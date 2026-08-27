; RUN: %opt -passes="grace-vec-hints" -S %s | FileCheck %s --check-prefix=STRICT
; RUN: %opt -passes="grace-vec-hints" -grace-fp-reassoc -S %s | FileCheck %s --check-prefix=REASSOC
; RUN: %opt -passes="grace-vec-hints" -grace-fp-reassoc -grace-interleave=4 -S %s | FileCheck %s --check-prefix=IC4
;
; x86 has no in-order vector FP reduction, so a strict fadd chain blocks the
; vectorizer. -grace-fp-reassoc lifts the blocker by granting 'reassoc' to the
; reduction chain (changing rounding, hence opt-in). On x86 the pass has no
; interleave opinion of its own; -grace-interleave adds one.

target triple = "x86_64-unknown-linux-gnu"

define float @dot(ptr noalias %x, ptr noalias %y, i64 %n) {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %s = phi float [ 0.0, %entry ], [ %s.next, %body ]
  %xp = getelementptr inbounds float, ptr %x, i64 %i
  %yp = getelementptr inbounds float, ptr %y, i64 %i
  %xv = load float, ptr %xp
  %yv = load float, ptr %yp
  %m = fmul float %xv, %yv
  %s.next = fadd float %s, %m
  %inc = add nuw nsw i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret float %s.next
}

; STRICT-LABEL: define float @dot
; STRICT:         %s = phi float
; STRICT:         %s.next = fadd float %s, %m
; STRICT:         br i1 %cmp, label %body, label %exit{{$}}

; REASSOC-LABEL: define float @dot
; REASSOC:         %s = phi reassoc float
; REASSOC:         %s.next = fadd reassoc float %s, %m
; REASSOC:         br i1 %cmp, label %body, label %exit{{$}}

; IC4-LABEL: define float @dot
; IC4:             %s.next = fadd reassoc float %s, %m
; IC4:             br i1 %cmp, label %body, label %exit, !llvm.loop ![[DOT:[0-9]+]]
; IC4-DAG: ![[DOT]] = distinct !{![[DOT]], ![[IC:[0-9]+]]}
; IC4-DAG: ![[IC]] = !{!"llvm.loop.interleave.count", i32 4}

; A reduction that also has another blocker (a call) is left strict.
declare float @opaque(float)

define float @dot_call(ptr noalias %x, i64 %n) {
entry:
  br label %body

body:
  %i = phi i64 [ 0, %entry ], [ %inc, %body ]
  %s = phi float [ 0.0, %entry ], [ %s.next, %body ]
  %xp = getelementptr inbounds float, ptr %x, i64 %i
  %xv = load float, ptr %xp
  %m = call float @opaque(float %xv)
  %s.next = fadd float %s, %m
  %inc = add nuw nsw i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit

exit:
  ret float %s.next
}

; REASSOC-LABEL: define float @dot_call
; REASSOC:         %s.next = fadd float %s, %m
