; RUN: %opt -passes="grace-licm" -S %s | FileCheck %s
;
; Integer division can trap (q == 0). It may only be hoisted when it is
; guaranteed to execute anyway, i.e. its block dominates every loop exit.

; Exit test in the header: the body does not run when n <= 0, so hoisting the
; division would introduce a trap the original program never had.
define i32 @unguarded(i32 %p, i32 %q, i32 %n) {
entry:
  br label %header

header:
  %i = phi i32 [ 0, %entry ], [ %inc, %body ]
  %s = phi i32 [ 0, %entry ], [ %add, %body ]
  %cmp = icmp slt i32 %i, %n
  br i1 %cmp, label %body, label %exit

body:
  %div = sdiv i32 %p, %q
  %add = add i32 %s, %div
  %inc = add i32 %i, 1
  br label %header

exit:
  ret i32 %s
}

; CHECK-LABEL: define i32 @unguarded
; CHECK:       entry:
; CHECK-NEXT:    br label %header
; CHECK:       body:
; CHECK-NEXT:    %div = sdiv i32 %p, %q

; Rotated (do-while) form: the body is the header and dominates the exit, so
; the division executes on the first trip regardless. Hoisting is safe.
define i32 @guarded(i32 %p, i32 %q, i32 %n) {
entry:
  br label %body

body:
  %i = phi i32 [ 0, %entry ], [ %inc, %body ]
  %s = phi i32 [ 0, %entry ], [ %add, %body ]
  %div = sdiv i32 %p, %q
  %add = add i32 %s, %div
  %inc = add i32 %i, 1
  %cmp = icmp slt i32 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret i32 %add
}

; CHECK-LABEL: define i32 @guarded
; CHECK:       entry:
; CHECK-NEXT:    %div = sdiv i32 %p, %q
; CHECK-NEXT:    br label %body
; CHECK:       body:
; CHECK-NOT:     sdiv
; CHECK:         ret i32 %add
