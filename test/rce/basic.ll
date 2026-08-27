; RUN: %opt -passes="grace-rce" -S %s | FileCheck %s
;
; Identical pure computations are replaced by the first (dominating) copy.
; Commutative operands are canonicalised, so b+a reuses a+b. Once the two GEPs
; collapse, the second load reads the same address and is forwarded too.

define i64 @index_math(ptr %p, i32 %i, i32 %j) {
entry:
  %a = sext i32 %i to i64
  %b = sext i32 %i to i64
  %sum1 = add i64 %a, %b
  %sum2 = add i64 %b, %a
  %g1 = getelementptr inbounds i64, ptr %p, i64 %sum1
  %g2 = getelementptr inbounds i64, ptr %p, i64 %sum2
  %v1 = load i64, ptr %g1
  %v2 = load i64, ptr %g2
  %r = add i64 %v1, %v2
  ret i64 %r
}

; CHECK-LABEL: define i64 @index_math
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %a = sext i32 %i to i64
; CHECK-NEXT:    %sum1 = add i64 %a, %a
; CHECK-NEXT:    %g1 = getelementptr inbounds i64, ptr %p, i64 %sum1
; CHECK-NEXT:    %v1 = load i64, ptr %g1
; CHECK-NEXT:    %r = add i64 %v1, %v1
; CHECK-NEXT:    ret i64 %r

; Different predicates / cast kinds are different computations.
define i1 @distinct(i32 %x, i32 %y) {
entry:
  %c1 = icmp slt i32 %x, %y
  %c2 = icmp sgt i32 %x, %y
  %z1 = zext i32 %x to i64
  %z2 = sext i32 %x to i64
  %e = icmp eq i64 %z1, %z2
  %r1 = xor i1 %c1, %c2
  %r = xor i1 %r1, %e
  ret i1 %r
}

; CHECK-LABEL: define i1 @distinct
; CHECK:         icmp slt
; CHECK-NEXT:    icmp sgt
; CHECK-NEXT:    zext
; CHECK-NEXT:    sext

; Only facts true of both copies survive the merge: `add nsw` + `add` -> `add`.
define i32 @flags(i32 %x, i32 %y) {
entry:
  %a = add nsw i32 %x, %y
  %b = add i32 %x, %y
  %r = mul i32 %a, %b
  ret i32 %r
}

; CHECK-LABEL: define i32 @flags
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %a = add i32 %x, %y
; CHECK-NEXT:    %r = mul i32 %a, %a
