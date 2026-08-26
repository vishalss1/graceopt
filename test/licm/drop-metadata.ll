; RUN: %opt -passes="grace-licm" -S %s | FileCheck %s
;
; A speculated load (dereferenceable pointer, exit test in the header) may now
; execute on a path where it did not before. Metadata whose violation is
; immediate undefined behaviour (!noundef) must be dropped when hoisting.
; (!range/!nonnull/!align only yield poison and may legally be kept.)

define i32 @spec_load(ptr dereferenceable(4) align 4 %p, i32 %n) {
entry:
  br label %header

header:
  %i = phi i32 [ 0, %entry ], [ %inc, %body ]
  %s = phi i32 [ 0, %entry ], [ %add, %body ]
  %cmp = icmp slt i32 %i, %n
  br i1 %cmp, label %body, label %exit

body:
  %v = load i32, ptr %p, align 4, !noundef !0
  %add = add i32 %s, %v
  %inc = add i32 %i, 1
  br label %header

exit:
  ret i32 %s
}

!0 = !{}

; CHECK-LABEL: define i32 @spec_load
; CHECK:       entry:
; CHECK-NEXT:    %v = load i32, ptr %p, align 4{{$}}
; CHECK-NEXT:    br label %header
