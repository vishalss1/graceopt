; RUN: %opt -passes="grace-licm" -S %s | FileCheck %s
;
; Loops are processed innermost-first. a*b is invariant in both loops and ends
; up in the outermost preheader; i*n depends on the outer induction variable
; and stops in the inner loop's preheader.

define void @nested(ptr noalias %out, float %a, float %b, i64 %n) {
entry:
  br label %outer

outer:
  %i = phi i64 [ 0, %entry ], [ %i.inc, %outer.latch ]
  br label %inner.ph

inner.ph:
  br label %inner

inner:
  %j = phi i64 [ 0, %inner.ph ], [ %j.inc, %inner ]
  %ab = fmul float %a, %b
  %idx = mul i64 %i, %n
  %k = add i64 %idx, %j
  %p = getelementptr inbounds float, ptr %out, i64 %k
  store float %ab, ptr %p
  %j.inc = add i64 %j, 1
  %jc = icmp slt i64 %j.inc, %n
  br i1 %jc, label %inner, label %outer.latch

outer.latch:
  %i.inc = add i64 %i, 1
  %ic = icmp slt i64 %i.inc, %n
  br i1 %ic, label %outer, label %exit

exit:
  ret void
}

; CHECK-LABEL: define void @nested
; CHECK:       entry:
; CHECK-NEXT:    %ab = fmul float %a, %b
; CHECK-NEXT:    br label %outer
; CHECK:       inner.ph:
; CHECK-NEXT:    %idx = mul i64 %i, %n
; CHECK-NEXT:    br label %inner
; CHECK:       inner:
; CHECK-NOT:     fmul
; CHECK-NOT:     mul i64 %i, %n
; CHECK:         %k = add i64 %idx, %j
