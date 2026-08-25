//===-- LoopOpportunityAnalysis.cpp - Loop optimization opportunity report ===//

#include "graceopt/LoopOpportunityAnalysis.h"

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"

#include <map>
#include <optional>
#include <tuple>
#include <vector>

using namespace llvm;
using namespace graceopt;

AnalysisKey LoopOpportunityAnalysis::Key;

namespace {

/// Does any instruction in the loop possibly write memory that \p Load reads?
bool loadMayBeClobberedInLoop(LoadInst &Load, Loop &L, AAResults &AA) {
  MemoryLocation Loc = MemoryLocation::get(&Load);
  for (BasicBlock *BB : L.blocks())
    for (Instruction &I : *BB)
      if (I.mayWriteToMemory() && isModSet(AA.getModRefInfo(&I, Loc)))
        return true;
  return false;
}

/// Decide whether \p I is a loop-invariant computation that could be hoisted
/// to the preheader of \p L. Mirrors the legality rules GraceLICM applies.
std::optional<InvariantCandidate>
classifyInvariant(Instruction &I, Loop &L, AAResults &AA, DominatorTree &DT,
                  const SmallPtrSetImpl<const Instruction *> &KnownInvariant) {
  if (isa<PHINode>(I) || I.isTerminator() || I.isEHPad())
    return std::nullopt;
  // Operands must be invariant either because they are defined outside the
  // loop, or because they are themselves candidates found earlier (so that
  // chains like `t = a*b; u = t/c` are discovered transitively).
  for (Value *Op : I.operands()) {
    if (L.isLoopInvariant(Op))
      continue;
    if (auto *OpI = dyn_cast<Instruction>(Op); OpI && KnownInvariant.count(OpI))
      continue;
    return std::nullopt;
  }
  // Anything that writes memory, throws, or has other side effects stays put.
  if (I.mayWriteToMemory() || I.mayThrow() || !I.willReturn())
    return std::nullopt;
  if (isa<AllocaInst>(I) || isa<CallBase>(I) && !isa<IntrinsicInst>(I))
    return std::nullopt;
  if (auto *Load = dyn_cast<LoadInst>(&I)) {
    if (!Load->isSimple())
      return std::nullopt;
    if (loadMayBeClobberedInLoop(*Load, L, AA))
      return std::nullopt;
  } else if (I.mayReadFromMemory()) {
    // Memory-reading intrinsics etc.: be conservative.
    return std::nullopt;
  }

  InvariantCandidate C;
  C.I = &I;
  C.SafeToSpeculate = isSafeToSpeculativelyExecute(&I, /*CtxI=*/nullptr,
                                                   /*AC=*/nullptr, &DT);
  if (!C.SafeToSpeculate) {
    // Not speculatable (e.g. a division that might trap, or a load from a
    // pointer we cannot prove dereferenceable). It is still hoistable when the
    // instruction is guaranteed to execute on every iteration, i.e. its block
    // dominates every loop exit.
    SmallVector<BasicBlock *, 4> Exits;
    L.getExitBlocks(Exits);
    bool DominatesExits = !Exits.empty();
    for (BasicBlock *E : Exits)
      if (!DT.dominates(I.getParent(), E)) {
        DominatesExits = false;
        break;
      }
    if (!DominatesExits)
      return std::nullopt;
  }
  return C;
}

/// Is \p I a side-effect-free computation whose result depends only on its
/// operands? Such instructions can be value-numbered.
bool isPureComputation(const Instruction &I) {
  if (isa<PHINode>(I) || isa<AllocaInst>(I) || isa<LandingPadInst>(I) ||
      I.isTerminator() || I.isEHPad())
    return false;
  if (I.mayReadOrWriteMemory() || I.mayHaveSideEffects())
    return false;
  if (auto *CB = dyn_cast<CallBase>(&I))
    return isa<IntrinsicInst>(CB) && CB->doesNotAccessMemory();
  return true;
}

/// Structural key identifying "the same computation". Operands of commutative
/// instructions are canonicalised so `a+b` and `b+a` collide.
using ExprKey = std::tuple<unsigned, Type *, unsigned, std::vector<Value *>>;

ExprKey makeExprKey(const Instruction &I) {
  unsigned Extra = 0;
  if (auto *Cmp = dyn_cast<CmpInst>(&I))
    Extra = Cmp->getPredicate();
  else if (auto *Cast = dyn_cast<CastInst>(&I))
    Extra = Cast->getOpcode();
  else if (auto *GEP = dyn_cast<GetElementPtrInst>(&I))
    Extra = GEP->getSourceElementType()->getTypeID();
  else if (auto *CB = dyn_cast<CallBase>(&I))
    Extra = CB->getCalledFunction() ? CB->getCalledFunction()->getIntrinsicID()
                                    : 0;
  std::vector<Value *> Ops(I.op_begin(), I.op_end());
  if (I.isCommutative() && Ops.size() == 2 && Ops[0] > Ops[1])
    std::swap(Ops[0], Ops[1]);
  return {I.getOpcode(), I.getType(), Extra, std::move(Ops)};
}

/// Find instructions in the loop that duplicate an earlier identical pure
/// computation. Blocks are visited in dominator-tree order so the "original"
/// is always the one that executes first.
void findRedundancies(Loop &L, DominatorTree &DT,
                      std::vector<RedundantPair> &Out) {
  std::map<ExprKey, const Instruction *> Seen;
  // Walk the dominator subtree rooted at the header; loop blocks are visited
  // only after every block that dominates them.
  for (DomTreeNode *N : depth_first(DT.getNode(L.getHeader()))) {
    BasicBlock *BB = N->getBlock();
    if (!L.contains(BB))
      continue;
    for (Instruction &I : *BB) {
      if (!isPureComputation(I))
        continue;
      ExprKey K = makeExprKey(I);
      auto It = Seen.find(K);
      if (It == Seen.end()) {
        Seen.emplace(std::move(K), &I);
        continue;
      }
      // Only a dominating original makes the duplicate fully redundant; a
      // sibling-branch twin would need partial redundancy elimination.
      if (DT.dominates(It->second, &I))
        Out.push_back({It->second, &I});
    }
  }
}

LoopReport analyzeLoop(Loop &L, ScalarEvolution &SE, AAResults &AA,
                       DominatorTree &DT) {
  LoopReport R;
  R.L = &L;
  R.HeaderName = L.getHeader()->hasName() ? L.getHeader()->getName().str()
                                          : std::string("<unnamed>");
  R.Depth = L.getLoopDepth();
  R.NumBlocks = L.getNumBlocks();
  for (BasicBlock *BB : L.blocks())
    R.NumInsts += BB->size();
  R.TripCount = SE.getSmallConstantTripCount(&L);
  R.IsInnermost = L.isInnermost();

  // Iterate to a fixpoint so that invariant chains are picked up regardless
  // of the order blocks are visited in.
  SmallPtrSet<const Instruction *, 16> Known;
  bool Changed = true;
  while (Changed) {
    Changed = false;
    for (BasicBlock *BB : L.blocks())
      for (Instruction &I : *BB) {
        if (Known.count(&I))
          continue;
        if (auto C = classifyInvariant(I, L, AA, DT, Known)) {
          Known.insert(&I);
          R.Invariants.push_back(*C);
          Changed = true;
        }
      }
  }
  findRedundancies(L, DT, R.Redundancies);
  return R;
}

} // namespace

LoopOpportunityAnalysis::Result
LoopOpportunityAnalysis::run(Function &F, FunctionAnalysisManager &FAM) {
  auto &LI = FAM.getResult<LoopAnalysis>(F);
  auto &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);
  auto &AA = FAM.getResult<AAManager>(F);
  auto &DT = FAM.getResult<DominatorTreeAnalysis>(F);

  FunctionLoopReport Report;
  // Visit loops outermost-first in program order so the printed report reads
  // naturally; nested loops follow their parent.
  for (Loop *Top : LI) {
    for (Loop *L : depth_first(Top))
      Report.Loops.push_back(analyzeLoop(*L, SE, AA, DT));
  }
  return Report;
}

void FunctionLoopReport::print(raw_ostream &OS) const {
  if (Loops.empty()) {
    OS << "  (no loops)\n";
    return;
  }
  for (const LoopReport &R : Loops) {
    OS.indent(R.Depth * 2) << "loop '" << R.HeaderName << "' depth=" << R.Depth
                           << " blocks=" << R.NumBlocks
                           << " insts=" << R.NumInsts << " trip=";
    if (R.TripCount)
      OS << R.TripCount;
    else
      OS << "unknown";
    if (R.IsInnermost)
      OS << " innermost";
    OS << "\n";
    if (!R.Invariants.empty()) {
      OS.indent(R.Depth * 2 + 2) << "invariants=" << R.Invariants.size()
                                 << ":\n";
      for (const InvariantCandidate &C : R.Invariants) {
        OS.indent(R.Depth * 2 + 4)
            << (C.SafeToSpeculate ? "[speculatable] " : "[guarded]      ");
        C.I->print(OS, /*IsForDebug=*/true);
        OS << "\n";
      }
    }
    if (!R.Redundancies.empty()) {
      OS.indent(R.Depth * 2 + 2) << "redundant=" << R.Redundancies.size()
                                 << ":\n";
      for (const RedundantPair &P : R.Redundancies) {
        OS.indent(R.Depth * 2 + 4);
        P.Duplicate->print(OS, /*IsForDebug=*/true);
        OS << "  ; duplicates ";
        P.Original->printAsOperand(OS, /*PrintType=*/false);
        OS << "\n";
      }
    }
  }
}

PreservedAnalyses LoopOpportunityPrinterPass::run(Function &F,
                                                  FunctionAnalysisManager &FAM) {
  OS << "GraceOpt loop report for function '" << F.getName() << "':\n";
  FAM.getResult<LoopOpportunityAnalysis>(F).print(OS);
  return PreservedAnalyses::all();
}
