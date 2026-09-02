; RUN: %opt -passes="grace-vec-hints" -grace-force-vectorize -grace-prefer-scalable -verify-each -S %s | FileCheck %s

target triple = "aarch64-unknown-linux-gnu"
define void @disabled(ptr noalias %x, ptr noalias %y, i64 %n) #0 {
entry:
  br label %body
body:
  %i = phi i64 [0, %entry], [%inc, %body]
  %xp = getelementptr float, ptr %x, i64 %i
  %yp = getelementptr float, ptr %y, i64 %i
  %v = load float, ptr %xp
  store float %v, ptr %yp
  %inc = add nuw nsw i64 %i, 1
  %cmp = icmp slt i64 %inc, %n
  br i1 %cmp, label %body, label %exit, !llvm.loop !0
exit:
  ret void
}
attributes #0 = { "target-cpu"="neoverse-v2" "target-features"="+sve2,-sve" }
!0 = distinct !{!0, !1}
!1 = !{!"llvm.loop.vectorize.enable", i1 false}
; CHECK-NOT: llvm.loop.interleave.count
; CHECK-NOT: llvm.loop.vectorize.scalable.enable
; CHECK: !{!"llvm.loop.vectorize.enable", i1 false}
; CHECK-NOT: llvm.loop.interleave.count
; CHECK-NOT: llvm.loop.vectorize.scalable.enable
