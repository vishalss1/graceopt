; RUN: %opt -passes="grace-rce" -S %s | FileCheck %s
;
; Block-local memory forwarding: a load may reuse an earlier load or store of
; the same (pointer, type) in the same block as long as nothing that may write
; memory sits in between. Facts never cross block boundaries.

define i32 @reload(ptr %p) {
entry:
  %a = load i32, ptr %p
  %b = load i32, ptr %p
  %r = add i32 %a, %b
  ret i32 %r
}

; CHECK-LABEL: define i32 @reload
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %a = load i32, ptr %p
; CHECK-NEXT:    %r = add i32 %a, %a

define i32 @store_forward(ptr %p, i32 %v) {
entry:
  store i32 %v, ptr %p
  %a = load i32, ptr %p
  ret i32 %a
}

; CHECK-LABEL: define i32 @store_forward
; CHECK-NEXT:  entry:
; CHECK-NEXT:    store i32 %v, ptr %p
; CHECK-NEXT:    ret i32 %v

declare void @opaque()

define i32 @call_between(ptr %p) {
entry:
  %a = load i32, ptr %p
  call void @opaque()
  %b = load i32, ptr %p
  %r = add i32 %a, %b
  ret i32 %r
}

; CHECK-LABEL: define i32 @call_between
; CHECK:         %a = load i32, ptr %p
; CHECK-NEXT:    call void @opaque()
; CHECK-NEXT:    %b = load i32, ptr %p

define i32 @across_blocks(ptr %p, i1 %c) {
entry:
  %a = load i32, ptr %p
  br i1 %c, label %then, label %exit

then:
  %b = load i32, ptr %p
  br label %exit

exit:
  %phi = phi i32 [ %a, %entry ], [ %b, %then ]
  ret i32 %phi
}

; CHECK-LABEL: define i32 @across_blocks
; CHECK:       then:
; CHECK-NEXT:    %b = load i32, ptr %p

; Volatile loads are never touched, and a type mismatch is a different access.
define i64 @volatile_and_type(ptr %p) {
entry:
  %a = load volatile i32, ptr %p
  %b = load volatile i32, ptr %p
  %c = load i64, ptr %p
  %d = load i32, ptr %p
  %ab = add i32 %a, %b
  %abd = add i32 %ab, %d
  %w = zext i32 %abd to i64
  %r = add i64 %c, %w
  ret i64 %r
}

; CHECK-LABEL: define i64 @volatile_and_type
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %a = load volatile i32, ptr %p
; CHECK-NEXT:    %b = load volatile i32, ptr %p
; CHECK-NEXT:    %c = load i64, ptr %p
; CHECK-NEXT:    %d = load i32, ptr %p
