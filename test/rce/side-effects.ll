; RUN: %opt -passes="grace-rce" -S %s | FileCheck %s
;
; Anything that touches memory or has side effects is never merged: two calls
; to an opaque function may return different values, and two loads of the same
; address may observe a store in between.

declare i32 @opaque(i32)
declare float @llvm.sqrt.f32(float)

define i32 @calls(i32 %x) {
entry:
  %a = call i32 @opaque(i32 %x)
  %b = call i32 @opaque(i32 %x)
  %r = add i32 %a, %b
  ret i32 %r
}

; CHECK-LABEL: define i32 @calls
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %a = call i32 @opaque(i32 %x)
; CHECK-NEXT:    %b = call i32 @opaque(i32 %x)

define i32 @loads(ptr %p, ptr %q) {
entry:
  %a = load i32, ptr %p
  store i32 0, ptr %q
  %b = load i32, ptr %p
  %r = add i32 %a, %b
  ret i32 %r
}

; CHECK-LABEL: define i32 @loads
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %a = load i32, ptr %p
; CHECK-NEXT:    store i32 0, ptr %q
; CHECK-NEXT:    %b = load i32, ptr %p

; Pure, memory-free intrinsics are fair game.
define float @intrinsics(float %x) {
entry:
  %a = call float @llvm.sqrt.f32(float %x)
  %b = call float @llvm.sqrt.f32(float %x)
  %r = fadd float %a, %b
  ret float %r
}

; CHECK-LABEL: define float @intrinsics
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %a = call float @llvm.sqrt.f32(float %x)
; CHECK-NEXT:    %r = fadd float %a, %a
