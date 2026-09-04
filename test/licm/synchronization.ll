; RUN: %opt -passes="grace-licm" -verify-each -S %s | FileCheck %s

define i32 @acquire_loop(ptr %p, ptr %flag, i32 %n) {
entry:
  br label %body
body:
  %i = phi i32 [0, %entry], [%inc, %body]
  %sync = load atomic i32, ptr %flag acquire, align 4
  %v = load i32, ptr %p
  %inc = add i32 %i, 1
  %cmp = icmp slt i32 %inc, %n
  br i1 %cmp, label %body, label %exit
exit:
  ret i32 %v
}
; CHECK-LABEL: @acquire_loop
; CHECK: entry:
; CHECK-NEXT: br label %body
; CHECK: load atomic
; CHECK-NEXT: %v = load i32, ptr %p
