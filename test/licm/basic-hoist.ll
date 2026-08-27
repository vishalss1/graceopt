; RUN: %opt -passes="grace-licm" -S %s | FileCheck %s
; RUN: %opt -passes="grace-licm" -pass-remarks=grace-licm -disable-output %s 2>&1 | FileCheck %s --check-prefix=REMARK
;
; An invariant chain (a*b, then /c) in the loop body is hoisted to the
; preheader as a unit; the loop body keeps only iteration-dependent work.

define void @saxpy(ptr noalias %y, ptr noalias %x, float %a, float %b, float %c, i64 %n) {
entry:
  br label %header

header:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %cmp = icmp slt i64 %i, %n
  br i1 %cmp, label %body, label %exit

body:
  %mul = fmul float %a, %b
  %div = fdiv float %mul, %c
  %xp = getelementptr inbounds float, ptr %x, i64 %i
  %xv = load float, ptr %xp
  %yp = getelementptr inbounds float, ptr %y, i64 %i
  %yv = load float, ptr %yp
  %t = fmul float %div, %xv
  %r = fadd float %t, %yv
  store float %r, ptr %yp
  %inc = add nsw i64 %i, 1
  br label %header

exit:
  ret void
}

; CHECK-LABEL: define void @saxpy
; CHECK:       entry:
; CHECK-NEXT:    %mul = fmul float %a, %b
; CHECK-NEXT:    %div = fdiv float %mul, %c
; CHECK-NEXT:    br label %header
; CHECK:       body:
; CHECK-NOT:     fmul float %a, %b
; CHECK-NOT:     fdiv
; CHECK:         %t = fmul float %div, %xv
; CHECK:         store float %r, ptr %yp

; REMARK: remark: {{.*}}hoisted loop-invariant fmul out of loop 'header'
; REMARK: remark: {{.*}}hoisted loop-invariant fdiv out of loop 'header'
