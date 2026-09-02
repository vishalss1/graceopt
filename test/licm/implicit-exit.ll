; RUN: %opt -passes="grace-licm" -verify-each -S %s | FileCheck %s

declare void @may_exit()
define i32 @implicit_exit(ptr %p, i32 %n) {
entry:
  br label %body
body:
  %i = phi i32 [0, %entry], [%inc, %body]
  call void @may_exit()
  %v = load i32, ptr %p
  %inc = add i32 %i, 1
  %more = icmp slt i32 %inc, %n
  br i1 %more, label %body, label %exit
exit:
  ret i32 %v
}
; CHECK-LABEL: @implicit_exit
; CHECK: entry:
; CHECK-NEXT: br label %body
; CHECK: call void @may_exit()
; CHECK-NEXT: %v = load

; A readnone call may still unwind or fail to return before a trapping divide.
declare void @opaque() memory(none)
define i32 @divide_after_call(i32 %x, i32 %y, i32 %n) {
entry:
  br label %body
body:
  %i = phi i32 [0, %entry], [%inc, %body]
  call void @opaque()
  %v = sdiv i32 %x, %y
  %inc = add i32 %i, 1
  %more = icmp slt i32 %inc, %n
  br i1 %more, label %body, label %exit
exit:
  ret i32 %v
}
; CHECK-LABEL: @divide_after_call
; CHECK: entry:
; CHECK-NEXT: br label %body
; CHECK: call void @opaque()
; CHECK-NEXT: %v = sdiv
