; RUN: %opt -passes="grace-rce" -S %s | FileCheck %s
;
; A computation is only redundant if an identical one dominates it. Twins in
; sibling branches are left alone (that would be partial redundancy
; elimination); a copy in a dominated block is removed.

define i32 @siblings(i32 %x, i32 %y, i1 %c) {
entry:
  br i1 %c, label %left, label %right

left:
  %l = mul i32 %x, %y
  br label %join

right:
  %r = mul i32 %x, %y
  br label %join

join:
  %phi = phi i32 [ %l, %left ], [ %r, %right ]
  %again = mul i32 %x, %y
  %res = add i32 %phi, %again
  ret i32 %res
}

; CHECK-LABEL: define i32 @siblings
; CHECK:       left:
; CHECK-NEXT:    %l = mul i32 %x, %y
; CHECK:       right:
; CHECK-NEXT:    %r = mul i32 %x, %y
; CHECK:       join:
; CHECK-NEXT:    %phi = phi
; CHECK-NEXT:    %again = mul i32 %x, %y

define i32 @dominated(i32 %x, i32 %y, i1 %c) {
entry:
  %e = mul i32 %x, %y
  br i1 %c, label %then, label %else

then:
  %t = mul i32 %x, %y
  br label %join

else:
  %f = mul i32 %y, %x
  br label %join

join:
  %phi = phi i32 [ %t, %then ], [ %f, %else ]
  %j = mul i32 %x, %y
  %res = add i32 %phi, %j
  ret i32 %res
}

; CHECK-LABEL: define i32 @dominated
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %e = mul i32 %x, %y
; CHECK:       then:
; CHECK-NEXT:    br label %join
; CHECK:       else:
; CHECK-NEXT:    br label %join
; CHECK:       join:
; CHECK-NEXT:    %phi = phi i32 [ %e, %then ], [ %e, %else ]
; CHECK-NEXT:    %res = add i32 %phi, %e

; Loops: the redundant copy in the body is replaced across the back edge too,
; because the header dominates the body.
define i32 @in_loop(ptr %p, i32 %n, i32 %k) {
entry:
  br label %header

header:
  %i = phi i32 [ 0, %entry ], [ %inc, %header ]
  %s = phi i32 [ 0, %entry ], [ %add, %header ]
  %kk = mul i32 %k, %k
  %kk2 = mul i32 %k, %k
  %t = add i32 %kk, %kk2
  %add = add i32 %s, %t
  %inc = add i32 %i, 1
  %cmp = icmp slt i32 %inc, %n
  br i1 %cmp, label %header, label %exit

exit:
  ret i32 %add
}

; CHECK-LABEL: define i32 @in_loop
; CHECK:         %kk = mul i32 %k, %k
; CHECK-NEXT:    %t = add i32 %kk, %kk
