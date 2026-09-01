; RUN: %opt -passes="grace-rce" -verify-each -S %s | FileCheck %s

define i64 @gep_sizes(ptr %p, i64 %i) {
  %a = getelementptr [4 x i8], ptr %p, i64 %i
  %b = getelementptr [8 x i8], ptr %p, i64 %i
  %aa = ptrtoint ptr %a to i64
  %bb = ptrtoint ptr %b to i64
  %r = sub i64 %aa, %bb
  ret i64 %r
}
; CHECK-LABEL: @gep_sizes
; CHECK: getelementptr [4 x i8]
; CHECK: getelementptr [8 x i8]

define i32 @freezes(i32 %x) {
  %a = freeze i32 %x
  %b = freeze i32 %x
  %r = sub i32 %a, %b
  ret i32 %r
}
; CHECK-LABEL: @freezes
; CHECK: %a = freeze
; CHECK-NEXT: %b = freeze

define i32 @aggregate({i32, i32} %x) {
  %a = extractvalue {i32, i32} %x, 0
  %b = extractvalue {i32, i32} %x, 1
  %r = sub i32 %a, %b
  ret i32 %r
}
; CHECK-LABEL: @aggregate
; CHECK: extractvalue { i32, i32 } %x, 0
; CHECK: extractvalue { i32, i32 } %x, 1
