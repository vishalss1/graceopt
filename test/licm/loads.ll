; RUN: %opt -passes="grace-licm" -S %s | FileCheck %s
;
; A load from an invariant address is only invariant if nothing in the loop
; may write to that memory.

; %dst and %src may alias, so the store could change what the load reads.
define void @clobbered(ptr %dst, ptr %src, i64 %n) {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %v = load i32, ptr %src
  %p = getelementptr inbounds i32, ptr %dst, i64 %i
  store i32 %v, ptr %p
  %inc = add i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret void
}

; CHECK-LABEL: define void @clobbered
; CHECK:       entry:
; CHECK-NEXT:    br label %body
; CHECK:       body:
; CHECK:         %v = load i32, ptr %src

; With noalias the store cannot touch %src; the load executes on every trip
; (rotated loop), so it is hoisted even without a dereferenceable attribute.
define void @disjoint(ptr noalias %dst, ptr noalias %src, i64 %n) {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %v = load i32, ptr %src
  %p = getelementptr inbounds i32, ptr %dst, i64 %i
  store i32 %v, ptr %p
  %inc = add i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret void
}

; CHECK-LABEL: define void @disjoint
; CHECK:       entry:
; CHECK-NEXT:    %v = load i32, ptr %src
; CHECK-NEXT:    br label %body
; CHECK:       body:
; CHECK-NOT:     load

; A call that may write memory clobbers any pointer that it could reach. %src
; is not noalias here, so the callee may legitimately write through it.
declare void @opaque()

define void @call_clobber(ptr noalias %dst, ptr %src, i64 %n) {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %v = load i32, ptr %src
  call void @opaque()
  %p = getelementptr inbounds i32, ptr %dst, i64 %i
  store i32 %v, ptr %p
  %inc = add i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret void
}

; CHECK-LABEL: define void @call_clobber
; CHECK:       body:
; CHECK:         %v = load i32, ptr %src
; CHECK-NEXT:    call void @opaque()
