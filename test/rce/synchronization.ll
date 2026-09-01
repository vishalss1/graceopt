; RUN: %opt -passes="grace-rce" -verify-each -S %s | FileCheck %s

define i32 @acquire(ptr %p, ptr %flag) {
  %a = load i32, ptr %p
  %sync = load atomic i32, ptr %flag acquire, align 4
  %b = load i32, ptr %p
  %r = add i32 %a, %b
  ret i32 %r
}
; CHECK-LABEL: @acquire
; CHECK: load atomic
; CHECK-NEXT: %b = load i32, ptr %p

define i32 @barrier(ptr %p) {
  %a = load i32, ptr %p
  fence acquire
  %b = load i32, ptr %p
  %r = add i32 %a, %b
  ret i32 %r
}
; CHECK-LABEL: @barrier
; CHECK: fence acquire
; CHECK-NEXT: %b = load i32, ptr %p

define i32 @range_poison(ptr %p) {
  %a = load i32, ptr %p, !range !0
  %b = load i32, ptr %p
  ret i32 %b
}
!0 = !{i32 0, i32 10}
; CHECK-LABEL: @range_poison
; CHECK: %a = load i32, ptr %p, align 4{{$}}
; CHECK-NEXT: ret i32 %a
