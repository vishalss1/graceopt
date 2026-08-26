; RUN: %opt -passes="print<grace-loop-analysis>" -disable-output %s 2>&1 | FileCheck %s
;
; The analysis report lists invariants, redundancies and the vectorization
; verdict for each loop.

define float @dot(ptr noalias %x, ptr noalias %y, i64 %n) {
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

; CHECK-LABEL: GraceOpt loop report for function 'dot':
; CHECK-NEXT:  loop 'body' depth=1 blocks=1 insts={{[0-9]+}} trip=unknown innermost
; CHECK-NEXT:  memory: loads=2 stores=0 affine=2 uniform=0 reductions=1 (ordered-fp)
; CHECK-NEXT:  vectorize: blocked
; CHECK-NEXT:  - floating-point reduction lacks 'reassoc'

define void @scale(ptr noalias %y, ptr noalias %x, float %a, float %b, i64 %n) {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %ab = fmul float %a, %b
  %xp = getelementptr inbounds float, ptr %x, i64 %i
  %xv = load float, ptr %xp
  %r = fmul float %xv, %ab
  %yp = getelementptr inbounds float, ptr %y, i64 %i
  %yp.dup = getelementptr inbounds float, ptr %y, i64 %i
  store float %r, ptr %yp.dup
  %inc = add nuw nsw i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret void
}

; CHECK-LABEL: GraceOpt loop report for function 'scale':
; CHECK-NEXT:  loop 'body' depth=1
; CHECK-NEXT:  invariants=1:
; CHECK-NEXT:  [speculatable]   %ab = fmul float %a, %b
; CHECK-NEXT:  redundant=1:
; CHECK-NEXT:  %yp.dup = getelementptr inbounds float, ptr %y, i64 %i  ; duplicates %yp
; CHECK-NEXT:  memory: loads=1 stores=1 affine=2 uniform=0 reductions=0
; CHECK-NEXT:  vectorize: candidate
