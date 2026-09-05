; RUN: %opt -passes="grace-vec-hints,grace-vec-hints" -verify-each -S %s | FileCheck %s --check-prefix=V2
; RUN: %opt -passes="grace-vec-hints" -S %s | FileCheck %s --check-prefix=V2
; RUN: %opt -passes="grace-vec-hints" -grace-interleave=-1 -S %s | FileCheck %s --check-prefix=NOHINT
; RUN: %opt -passes="grace-vec-hints" -grace-fp-reassoc -S %s | FileCheck %s --check-prefix=REASSOC
; RUN: %opt -passes="grace-vec-hints" -grace-prefer-scalable -grace-force-vectorize -S %s | FileCheck %s --check-prefix=SVE
;
; On Neoverse V2 (NVIDIA Grace) candidate loops get interleave.count=4.
; Loops the vectorizer would reject are left untouched.

target triple = "aarch64-unknown-linux-gnu"

define void @axpy(ptr noalias %y, ptr noalias %x, float %a, i64 %n) #0 {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %xp = getelementptr inbounds float, ptr %x, i64 %i
  %xv = load float, ptr %xp
  %yp = getelementptr inbounds float, ptr %y, i64 %i
  %yv = load float, ptr %yp
  %m = fmul float %a, %xv
  %r = fadd float %m, %yv
  store float %r, ptr %yp
  %inc = add nuw nsw i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret void
}

; V2-LABEL: define void @axpy
; V2:         br i1 %cmp, label %body, label %exit, !llvm.loop ![[AXPY:[0-9]+]]
; NOHINT-LABEL: define void @axpy
; NOHINT-NOT:   !llvm.loop
; NOHINT-LABEL: define float @dot
; SVE-LABEL:  define void @axpy
; SVE:          br i1 %cmp, label %body, label %exit, !llvm.loop ![[AXPY:[0-9]+]]

define float @dot(ptr noalias %x, ptr noalias %y, i64 %n) #0 {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %s = phi float [ 0.0, %entry ], [ %s.next, %body ]
  %xp = getelementptr inbounds float, ptr %x, i64 %i
  %yp = getelementptr inbounds float, ptr %y, i64 %i
  %xv = load float, ptr %xp
  %yv = load float, ptr %yp
  %m = fmul float %xv, %yv
  %s.next = fadd float %s, %m
  %inc = add nuw nsw i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret float %s.next
}

; AArch64 supports strict in-order FP reductions, so even without reassoc the
; ordered reduction is a candidate here (contrast with reassoc-x86.ll).
; V2-LABEL: define float @dot
; V2:         %s.next = fadd float %s, %m
; V2:         br i1 %cmp, label %body, label %exit, !llvm.loop ![[DOT:[0-9]+]]
; REASSOC-LABEL: define float @dot
; REASSOC:       %s = phi float
; REASSOC:       %s.next = fadd float %s, %m
; REASSOC:       br i1 %cmp, label %body, label %exit, !llvm.loop ![[DOT:[0-9]+]]

; A user pragma on the loop wins over our heuristic.
define void @user_hint(ptr noalias %y, ptr noalias %x, i64 %n) #0 {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %xp = getelementptr inbounds float, ptr %x, i64 %i
  %xv = load float, ptr %xp
  %yp = getelementptr inbounds float, ptr %y, i64 %i
  store float %xv, ptr %yp
  %inc = add nuw nsw i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit, !llvm.loop !0

exit:
  ret void
}

; V2-LABEL: define void @user_hint
; V2:         !llvm.loop ![[USER:[0-9]+]]

define void @gather(ptr noalias %y, ptr noalias %x, ptr noalias %idx, i64 %n) #0 {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %ip = getelementptr inbounds i32, ptr %idx, i64 %i
  %iv = load i32, ptr %ip
  %k = sext i32 %iv to i64
  %xp = getelementptr inbounds float, ptr %x, i64 %k
  %xv = load float, ptr %xp
  %yp = getelementptr inbounds float, ptr %y, i64 %i
  store float %xv, ptr %yp
  %inc = add nuw nsw i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret void
}

; V2-LABEL: define void @gather
; V2:         br i1 %cmp, label %body, label %exit{{$}}

attributes #0 = { "target-cpu"="neoverse-v2" "target-features"="+neon,+sve,+sve2,+v9a" }

!0 = distinct !{!0, !1}
!1 = !{!"llvm.loop.interleave.count", i32 1}

; V2-DAG: ![[AXPY]] = distinct !{![[AXPY]], ![[IC4:[0-9]+]]}
; V2-DAG: ![[IC4]] = !{!"llvm.loop.interleave.count", i32 4}
; V2-DAG: ![[DOT]] = distinct !{![[DOT]], ![[IC4]]}
; V2-DAG: ![[USER]] = distinct !{![[USER]], ![[IC1:[0-9]+]]}
; V2-DAG: ![[IC1]] = !{!"llvm.loop.interleave.count", i32 1}
; REASSOC-DAG: ![[DOT]] = distinct !{![[DOT]], ![[IC4:[0-9]+]]}
; REASSOC-DAG: ![[IC4]] = !{!"llvm.loop.interleave.count", i32 4}
; SVE-DAG: ![[AXPY]] = distinct !{![[AXPY]], ![[IC:[0-9]+]], ![[SC:[0-9]+]], ![[EN:[0-9]+]]}
; SVE-DAG: ![[IC]] = !{!"llvm.loop.interleave.count", i32 4}
; SVE-DAG: ![[SC]] = !{!"llvm.loop.vectorize.scalable.enable", i32 1}
; SVE-DAG: ![[EN]] = !{!"llvm.loop.vectorize.enable", i32 1}
