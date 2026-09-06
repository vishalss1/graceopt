; ModuleID = 'D:\graceopt\bench\codegen\kernels.c'
source_filename = "D:\\graceopt\\bench\\codegen\\kernels.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "aarch64-unknown-linux-gnu"

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: readwrite) vscale_range(1,1)
define dso_local void @saxpy(ptr noalias noundef captures(none) %0, ptr noalias noundef readonly captures(none) %1, float noundef %2, i64 noundef %3) local_unnamed_addr #0 !dbg !12 {
  %5 = icmp eq i64 %3, 0, !dbg !16
  br i1 %5, label %61, label %6, !dbg !17

6:                                                ; preds = %4
  %7 = icmp ult i64 %3, 4, !dbg !17
  br i1 %7, label %59, label %8, !dbg !17

8:                                                ; preds = %6
  %9 = icmp ult i64 %3, 16, !dbg !17
  br i1 %9, label %43, label %10, !dbg !17

10:                                               ; preds = %8
  %11 = and i64 %3, 12
  %12 = and i64 %3, -16
  %13 = insertelement <4 x float> poison, float %2, i64 0
  %14 = shufflevector <4 x float> %13, <4 x float> poison, <4 x i32> zeroinitializer
  br label %15, !dbg !17

15:                                               ; preds = %15, %10
  %16 = phi i64 [ 0, %10 ], [ %37, %15 ], !dbg !18
  %17 = getelementptr inbounds nuw float, ptr %1, i64 %16, !dbg !19
  %18 = getelementptr inbounds nuw i8, ptr %17, i64 16, !dbg !19
  %19 = getelementptr inbounds nuw i8, ptr %17, i64 32, !dbg !19
  %20 = getelementptr inbounds nuw i8, ptr %17, i64 48, !dbg !19
  %21 = load <4 x float>, ptr %17, align 4, !dbg !19, !tbaa !20
  %22 = load <4 x float>, ptr %18, align 4, !dbg !19, !tbaa !20
  %23 = load <4 x float>, ptr %19, align 4, !dbg !19, !tbaa !20
  %24 = load <4 x float>, ptr %20, align 4, !dbg !19, !tbaa !20
  %25 = getelementptr inbounds nuw float, ptr %0, i64 %16, !dbg !22
  %26 = getelementptr inbounds nuw i8, ptr %25, i64 16, !dbg !22
  %27 = getelementptr inbounds nuw i8, ptr %25, i64 32, !dbg !22
  %28 = getelementptr inbounds nuw i8, ptr %25, i64 48, !dbg !22
  %29 = load <4 x float>, ptr %25, align 4, !dbg !22, !tbaa !20
  %30 = load <4 x float>, ptr %26, align 4, !dbg !22, !tbaa !20
  %31 = load <4 x float>, ptr %27, align 4, !dbg !22, !tbaa !20
  %32 = load <4 x float>, ptr %28, align 4, !dbg !22, !tbaa !20
  %33 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %14, <4 x float> %21, <4 x float> %29), !dbg !23
  %34 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %14, <4 x float> %22, <4 x float> %30), !dbg !23
  %35 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %14, <4 x float> %23, <4 x float> %31), !dbg !23
  %36 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %14, <4 x float> %24, <4 x float> %32), !dbg !23
  store <4 x float> %33, ptr %25, align 4, !dbg !24, !tbaa !20
  store <4 x float> %34, ptr %26, align 4, !dbg !24, !tbaa !20
  store <4 x float> %35, ptr %27, align 4, !dbg !24, !tbaa !20
  store <4 x float> %36, ptr %28, align 4, !dbg !24, !tbaa !20
  %37 = add nuw i64 %16, 16, !dbg !18
  %38 = icmp eq i64 %37, %12, !dbg !17
  br i1 %38, label %39, label %15, !dbg !17, !llvm.loop !25

39:                                               ; preds = %15
  %40 = icmp eq i64 %3, %12, !dbg !17
  br i1 %40, label %61, label %41, !dbg !17

41:                                               ; preds = %39
  %42 = icmp eq i64 %11, 0
  br i1 %42, label %59, label %43, !prof !29

43:                                               ; preds = %8, %41
  %44 = phi i64 [ %12, %41 ], [ 0, %8 ]
  %45 = and i64 %3, -4
  %46 = insertelement <4 x float> poison, float %2, i64 0
  %47 = shufflevector <4 x float> %46, <4 x float> poison, <4 x i32> zeroinitializer
  br label %48

48:                                               ; preds = %48, %43
  %49 = phi i64 [ %44, %43 ], [ %55, %48 ], !dbg !18
  %50 = getelementptr inbounds nuw float, ptr %1, i64 %49, !dbg !19
  %51 = load <4 x float>, ptr %50, align 4, !dbg !19, !tbaa !20
  %52 = getelementptr inbounds nuw float, ptr %0, i64 %49, !dbg !22
  %53 = load <4 x float>, ptr %52, align 4, !dbg !22, !tbaa !20
  %54 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %47, <4 x float> %51, <4 x float> %53), !dbg !23
  store <4 x float> %54, ptr %52, align 4, !dbg !24, !tbaa !20
  %55 = add nuw i64 %49, 4, !dbg !18
  %56 = icmp eq i64 %55, %45, !dbg !17
  br i1 %56, label %57, label %48, !dbg !17, !llvm.loop !30

57:                                               ; preds = %48
  %58 = icmp eq i64 %3, %45, !dbg !17
  br i1 %58, label %61, label %59, !dbg !17

59:                                               ; preds = %6, %41, %57
  %60 = phi i64 [ 0, %6 ], [ %12, %41 ], [ %45, %57 ]
  br label %62, !dbg !17

61:                                               ; preds = %62, %39, %57, %4
  ret void, !dbg !31

62:                                               ; preds = %59, %62
  %63 = phi i64 [ %69, %62 ], [ %60, %59 ]
  %64 = getelementptr inbounds nuw float, ptr %1, i64 %63, !dbg !19
  %65 = load float, ptr %64, align 4, !dbg !19, !tbaa !20
  %66 = getelementptr inbounds nuw float, ptr %0, i64 %63, !dbg !22
  %67 = load float, ptr %66, align 4, !dbg !22, !tbaa !20
  %68 = tail call float @llvm.fmuladd.f32(float %2, float %65, float %67), !dbg !23
  store float %68, ptr %66, align 4, !dbg !24, !tbaa !20
  %69 = add nuw i64 %63, 1, !dbg !18
  %70 = icmp eq i64 %69, %3, !dbg !16
  br i1 %70, label %61, label %62, !dbg !17, !llvm.loop !32
}

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare float @llvm.fmuladd.f32(float, float, float) #1

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) vscale_range(1,1)
define dso_local double @dot(ptr noalias noundef readonly captures(none) %0, ptr noalias noundef readonly captures(none) %1, i64 noundef %2) local_unnamed_addr #2 !dbg !33 {
  switch i64 %2, label %4 [
    i64 0, label %72
    i64 1, label %69
  ], !dbg !34

4:                                                ; preds = %3
  %5 = icmp ult i64 %2, 16, !dbg !34
  br i1 %5, label %50, label %6, !dbg !34

6:                                                ; preds = %4
  %7 = and i64 %2, 14
  %8 = and i64 %2, -16
  br label %9, !dbg !34

9:                                                ; preds = %9, %6
  %10 = phi i64 [ 0, %6 ], [ %44, %9 ], !dbg !35
  %11 = phi double [ 0.000000e+00, %6 ], [ %43, %9 ]
  %12 = getelementptr inbounds nuw float, ptr %0, i64 %10, !dbg !36
  %13 = getelementptr inbounds nuw i8, ptr %12, i64 16, !dbg !36
  %14 = getelementptr inbounds nuw i8, ptr %12, i64 32, !dbg !36
  %15 = getelementptr inbounds nuw i8, ptr %12, i64 48, !dbg !36
  %16 = load <vscale x 4 x float>, ptr %12, align 4, !dbg !36, !tbaa !20
  %17 = load <vscale x 4 x float>, ptr %13, align 4, !dbg !36, !tbaa !20
  %18 = load <vscale x 4 x float>, ptr %14, align 4, !dbg !36, !tbaa !20
  %19 = load <vscale x 4 x float>, ptr %15, align 4, !dbg !36, !tbaa !20
  %20 = fpext <vscale x 4 x float> %16 to <vscale x 4 x double>, !dbg !37
  %21 = fpext <vscale x 4 x float> %17 to <vscale x 4 x double>, !dbg !37
  %22 = fpext <vscale x 4 x float> %18 to <vscale x 4 x double>, !dbg !37
  %23 = fpext <vscale x 4 x float> %19 to <vscale x 4 x double>, !dbg !37
  %24 = getelementptr inbounds nuw float, ptr %1, i64 %10, !dbg !38
  %25 = getelementptr inbounds nuw i8, ptr %24, i64 16, !dbg !38
  %26 = getelementptr inbounds nuw i8, ptr %24, i64 32, !dbg !38
  %27 = getelementptr inbounds nuw i8, ptr %24, i64 48, !dbg !38
  %28 = load <vscale x 4 x float>, ptr %24, align 4, !dbg !38, !tbaa !20
  %29 = load <vscale x 4 x float>, ptr %25, align 4, !dbg !38, !tbaa !20
  %30 = load <vscale x 4 x float>, ptr %26, align 4, !dbg !38, !tbaa !20
  %31 = load <vscale x 4 x float>, ptr %27, align 4, !dbg !38, !tbaa !20
  %32 = fpext <vscale x 4 x float> %28 to <vscale x 4 x double>, !dbg !38
  %33 = fpext <vscale x 4 x float> %29 to <vscale x 4 x double>, !dbg !38
  %34 = fpext <vscale x 4 x float> %30 to <vscale x 4 x double>, !dbg !38
  %35 = fpext <vscale x 4 x float> %31 to <vscale x 4 x double>, !dbg !38
  %36 = fmul <vscale x 4 x double> %20, %32
  %37 = fmul <vscale x 4 x double> %21, %33
  %38 = fmul <vscale x 4 x double> %22, %34
  %39 = fmul <vscale x 4 x double> %23, %35
  %40 = tail call double @llvm.vector.reduce.fadd.nxv4f64(double %11, <vscale x 4 x double> %36), !dbg !39
  %41 = tail call double @llvm.vector.reduce.fadd.nxv4f64(double %40, <vscale x 4 x double> %37), !dbg !39
  %42 = tail call double @llvm.vector.reduce.fadd.nxv4f64(double %41, <vscale x 4 x double> %38), !dbg !39
  %43 = tail call double @llvm.vector.reduce.fadd.nxv4f64(double %42, <vscale x 4 x double> %39), !dbg !39
  %44 = add nuw i64 %10, 16, !dbg !35
  %45 = icmp eq i64 %44, %8, !dbg !34
  br i1 %45, label %46, label %9, !dbg !34, !llvm.loop !40

46:                                               ; preds = %9
  %47 = icmp eq i64 %2, %8, !dbg !34
  br i1 %47, label %72, label %48, !dbg !34

48:                                               ; preds = %46
  %49 = icmp eq i64 %7, 0
  br i1 %49, label %69, label %50, !prof !41

50:                                               ; preds = %4, %48
  %51 = phi i64 [ %8, %48 ], [ 0, %4 ]
  %52 = phi double [ %43, %48 ], [ 0.000000e+00, %4 ]
  %53 = and i64 %2, -2
  br label %54

54:                                               ; preds = %54, %50
  %55 = phi i64 [ %51, %50 ], [ %65, %54 ], !dbg !35
  %56 = phi double [ %52, %50 ], [ %64, %54 ]
  %57 = getelementptr inbounds nuw float, ptr %0, i64 %55, !dbg !36
  %58 = load <vscale x 2 x float>, ptr %57, align 4, !dbg !36, !tbaa !20
  %59 = fpext <vscale x 2 x float> %58 to <vscale x 2 x double>, !dbg !37
  %60 = getelementptr inbounds nuw float, ptr %1, i64 %55, !dbg !38
  %61 = load <vscale x 2 x float>, ptr %60, align 4, !dbg !38, !tbaa !20
  %62 = fpext <vscale x 2 x float> %61 to <vscale x 2 x double>, !dbg !38
  %63 = fmul <vscale x 2 x double> %59, %62
  %64 = tail call double @llvm.vector.reduce.fadd.nxv2f64(double %56, <vscale x 2 x double> %63), !dbg !39
  %65 = add nuw i64 %55, 2, !dbg !35
  %66 = icmp eq i64 %65, %53, !dbg !34
  br i1 %66, label %67, label %54, !dbg !34, !llvm.loop !42

67:                                               ; preds = %54
  %68 = icmp eq i64 %2, %53, !dbg !34
  br i1 %68, label %72, label %69, !dbg !34

69:                                               ; preds = %3, %48, %67
  %70 = phi i64 [ 0, %3 ], [ %8, %48 ], [ %53, %67 ]
  %71 = phi double [ 0.000000e+00, %3 ], [ %43, %48 ], [ %64, %67 ]
  br label %74, !dbg !34

72:                                               ; preds = %74, %46, %67, %3
  %73 = phi double [ 0.000000e+00, %3 ], [ %64, %67 ], [ %43, %46 ], [ %83, %74 ], !dbg !43
  ret double %73, !dbg !44

74:                                               ; preds = %69, %74
  %75 = phi i64 [ %84, %74 ], [ %70, %69 ]
  %76 = phi double [ %83, %74 ], [ %71, %69 ]
  %77 = getelementptr inbounds nuw float, ptr %0, i64 %75, !dbg !36
  %78 = load float, ptr %77, align 4, !dbg !36, !tbaa !20
  %79 = fpext float %78 to double, !dbg !37
  %80 = getelementptr inbounds nuw float, ptr %1, i64 %75, !dbg !38
  %81 = load float, ptr %80, align 4, !dbg !38, !tbaa !20
  %82 = fpext float %81 to double, !dbg !38
  %83 = tail call double @llvm.fmuladd.f64(double %79, double %82, double %76), !dbg !39
  %84 = add nuw i64 %75, 1, !dbg !35
  %85 = icmp eq i64 %84, %2, !dbg !45
  br i1 %85, label %72, label %74, !dbg !34, !llvm.loop !46
}

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.fmuladd.f64(double, double, double) #1

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: readwrite) vscale_range(1,1)
define dso_local void @invariant(ptr noalias noundef writeonly captures(none) %0, ptr noalias noundef readonly captures(none) %1, float noundef %2, float noundef %3, i64 noundef %4) local_unnamed_addr #0 !dbg !47 {
  %6 = icmp eq i64 %4, 0, !dbg !48
  br i1 %6, label %60, label %7, !dbg !49

7:                                                ; preds = %5
  %8 = tail call float @llvm.fmuladd.f32(float %2, float %2, float %3)
  %9 = fadd float %2, 1.000000e+00
  %10 = fdiv float %8, %9
  %11 = icmp ult i64 %4, 4, !dbg !49
  br i1 %11, label %58, label %12, !dbg !49

12:                                               ; preds = %7
  %13 = icmp ult i64 %4, 16, !dbg !49
  br i1 %13, label %43, label %14, !dbg !49

14:                                               ; preds = %12
  %15 = and i64 %4, 12
  %16 = and i64 %4, -16
  %17 = insertelement <4 x float> poison, float %10, i64 0
  %18 = shufflevector <4 x float> %17, <4 x float> poison, <4 x i32> zeroinitializer
  br label %19, !dbg !49

19:                                               ; preds = %19, %14
  %20 = phi i64 [ 0, %14 ], [ %37, %19 ], !dbg !50
  %21 = getelementptr inbounds nuw float, ptr %1, i64 %20, !dbg !51
  %22 = getelementptr inbounds nuw i8, ptr %21, i64 16, !dbg !51
  %23 = getelementptr inbounds nuw i8, ptr %21, i64 32, !dbg !51
  %24 = getelementptr inbounds nuw i8, ptr %21, i64 48, !dbg !51
  %25 = load <4 x float>, ptr %21, align 4, !dbg !51, !tbaa !20
  %26 = load <4 x float>, ptr %22, align 4, !dbg !51, !tbaa !20
  %27 = load <4 x float>, ptr %23, align 4, !dbg !51, !tbaa !20
  %28 = load <4 x float>, ptr %24, align 4, !dbg !51, !tbaa !20
  %29 = fmul <4 x float> %18, %25, !dbg !52
  %30 = fmul <4 x float> %18, %26, !dbg !52
  %31 = fmul <4 x float> %18, %27, !dbg !52
  %32 = fmul <4 x float> %18, %28, !dbg !52
  %33 = getelementptr inbounds nuw float, ptr %0, i64 %20, !dbg !53
  %34 = getelementptr inbounds nuw i8, ptr %33, i64 16, !dbg !54
  %35 = getelementptr inbounds nuw i8, ptr %33, i64 32, !dbg !54
  %36 = getelementptr inbounds nuw i8, ptr %33, i64 48, !dbg !54
  store <4 x float> %29, ptr %33, align 4, !dbg !54, !tbaa !20
  store <4 x float> %30, ptr %34, align 4, !dbg !54, !tbaa !20
  store <4 x float> %31, ptr %35, align 4, !dbg !54, !tbaa !20
  store <4 x float> %32, ptr %36, align 4, !dbg !54, !tbaa !20
  %37 = add nuw i64 %20, 16, !dbg !50
  %38 = icmp eq i64 %37, %16, !dbg !49
  br i1 %38, label %39, label %19, !dbg !49, !llvm.loop !55

39:                                               ; preds = %19
  %40 = icmp eq i64 %4, %16, !dbg !49
  br i1 %40, label %60, label %41, !dbg !49

41:                                               ; preds = %39
  %42 = icmp eq i64 %15, 0
  br i1 %42, label %58, label %43, !prof !29

43:                                               ; preds = %12, %41
  %44 = phi i64 [ %16, %41 ], [ 0, %12 ]
  %45 = and i64 %4, -4
  %46 = insertelement <4 x float> poison, float %10, i64 0
  %47 = shufflevector <4 x float> %46, <4 x float> poison, <4 x i32> zeroinitializer
  br label %48

48:                                               ; preds = %48, %43
  %49 = phi i64 [ %44, %43 ], [ %54, %48 ], !dbg !50
  %50 = getelementptr inbounds nuw float, ptr %1, i64 %49, !dbg !51
  %51 = load <4 x float>, ptr %50, align 4, !dbg !51, !tbaa !20
  %52 = fmul <4 x float> %47, %51, !dbg !52
  %53 = getelementptr inbounds nuw float, ptr %0, i64 %49, !dbg !53
  store <4 x float> %52, ptr %53, align 4, !dbg !54, !tbaa !20
  %54 = add nuw i64 %49, 4, !dbg !50
  %55 = icmp eq i64 %54, %45, !dbg !49
  br i1 %55, label %56, label %48, !dbg !49, !llvm.loop !56

56:                                               ; preds = %48
  %57 = icmp eq i64 %4, %45, !dbg !49
  br i1 %57, label %60, label %58, !dbg !49

58:                                               ; preds = %7, %41, %56
  %59 = phi i64 [ 0, %7 ], [ %16, %41 ], [ %45, %56 ]
  br label %61, !dbg !49

60:                                               ; preds = %61, %39, %56, %5
  ret void, !dbg !57

61:                                               ; preds = %58, %61
  %62 = phi i64 [ %67, %61 ], [ %59, %58 ]
  %63 = getelementptr inbounds nuw float, ptr %1, i64 %62, !dbg !51
  %64 = load float, ptr %63, align 4, !dbg !51, !tbaa !20
  %65 = fmul float %10, %64, !dbg !52
  %66 = getelementptr inbounds nuw float, ptr %0, i64 %62, !dbg !53
  store float %65, ptr %66, align 4, !dbg !54, !tbaa !20
  %67 = add nuw i64 %62, 1, !dbg !50
  %68 = icmp eq i64 %67, %4, !dbg !48
  br i1 %68, label %60, label %61, !dbg !49, !llvm.loop !58
}

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: readwrite) vscale_range(1,1)
define dso_local void @stencil(ptr noalias noundef writeonly captures(none) %0, ptr noalias noundef readonly captures(none) %1, i64 noundef %2) local_unnamed_addr #0 !dbg !59 {
  %4 = icmp ugt i64 %2, 2, !dbg !60
  br i1 %4, label %5, label %66, !dbg !61

5:                                                ; preds = %3
  %6 = getelementptr i8, ptr %1, i64 4
  %7 = load float, ptr %6, align 4, !dbg !62, !tbaa !20
  %8 = add i64 %2, -2, !dbg !61
  %9 = icmp ult i64 %8, 16, !dbg !61
  br i1 %9, label %62, label %10, !dbg !61

10:                                               ; preds = %5
  %11 = and i64 %8, -16
  %12 = or disjoint i64 %11, 2
  %13 = or disjoint i64 %11, 1
  %14 = insertelement <4 x float> poison, float %7, i64 3, !dbg !61
  br label %15, !dbg !61

15:                                               ; preds = %15, %10
  %16 = phi i64 [ 0, %10 ], [ %57, %15 ]
  %17 = phi <4 x float> [ %14, %10 ], [ %36, %15 ]
  %18 = or disjoint i64 %16, 1
  %19 = getelementptr float, ptr %1, i64 %18, !dbg !63
  %20 = getelementptr i8, ptr %19, i64 -4, !dbg !63
  %21 = getelementptr i8, ptr %19, i64 12, !dbg !63
  %22 = getelementptr i8, ptr %19, i64 28, !dbg !63
  %23 = getelementptr i8, ptr %19, i64 44, !dbg !63
  %24 = load <4 x float>, ptr %20, align 4, !dbg !63, !tbaa !20
  %25 = load <4 x float>, ptr %21, align 4, !dbg !63, !tbaa !20
  %26 = load <4 x float>, ptr %22, align 4, !dbg !63, !tbaa !20
  %27 = load <4 x float>, ptr %23, align 4, !dbg !63, !tbaa !20
  %28 = getelementptr inbounds nuw float, ptr %1, i64 %16, !dbg !64
  %29 = getelementptr inbounds nuw i8, ptr %28, i64 8, !dbg !64
  %30 = getelementptr inbounds nuw i8, ptr %28, i64 24, !dbg !64
  %31 = getelementptr inbounds nuw i8, ptr %28, i64 40, !dbg !64
  %32 = getelementptr inbounds nuw i8, ptr %28, i64 56, !dbg !64
  %33 = load <4 x float>, ptr %29, align 4, !dbg !64, !tbaa !20
  %34 = load <4 x float>, ptr %30, align 4, !dbg !64, !tbaa !20
  %35 = load <4 x float>, ptr %31, align 4, !dbg !64, !tbaa !20
  %36 = load <4 x float>, ptr %32, align 4, !dbg !64, !tbaa !20
  %37 = shufflevector <4 x float> %17, <4 x float> %33, <4 x i32> <i32 3, i32 4, i32 5, i32 6>
  %38 = shufflevector <4 x float> %33, <4 x float> %34, <4 x i32> <i32 3, i32 4, i32 5, i32 6>
  %39 = shufflevector <4 x float> %34, <4 x float> %35, <4 x i32> <i32 3, i32 4, i32 5, i32 6>
  %40 = shufflevector <4 x float> %35, <4 x float> %36, <4 x i32> <i32 3, i32 4, i32 5, i32 6>
  %41 = fmul <4 x float> %37, splat (float 5.000000e-01), !dbg !65
  %42 = fmul <4 x float> %38, splat (float 5.000000e-01), !dbg !65
  %43 = fmul <4 x float> %39, splat (float 5.000000e-01), !dbg !65
  %44 = fmul <4 x float> %40, splat (float 5.000000e-01), !dbg !65
  %45 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %24, <4 x float> splat (float 2.500000e-01), <4 x float> %41), !dbg !66
  %46 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %25, <4 x float> splat (float 2.500000e-01), <4 x float> %42), !dbg !66
  %47 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %26, <4 x float> splat (float 2.500000e-01), <4 x float> %43), !dbg !66
  %48 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %27, <4 x float> splat (float 2.500000e-01), <4 x float> %44), !dbg !66
  %49 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %33, <4 x float> splat (float 2.500000e-01), <4 x float> %45), !dbg !67
  %50 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %34, <4 x float> splat (float 2.500000e-01), <4 x float> %46), !dbg !67
  %51 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %35, <4 x float> splat (float 2.500000e-01), <4 x float> %47), !dbg !67
  %52 = tail call <4 x float> @llvm.fmuladd.v4f32(<4 x float> %36, <4 x float> splat (float 2.500000e-01), <4 x float> %48), !dbg !67
  %53 = getelementptr inbounds nuw float, ptr %0, i64 %18, !dbg !68
  %54 = getelementptr inbounds nuw i8, ptr %53, i64 16, !dbg !69
  %55 = getelementptr inbounds nuw i8, ptr %53, i64 32, !dbg !69
  %56 = getelementptr inbounds nuw i8, ptr %53, i64 48, !dbg !69
  store <4 x float> %49, ptr %53, align 4, !dbg !69, !tbaa !20
  store <4 x float> %50, ptr %54, align 4, !dbg !69, !tbaa !20
  store <4 x float> %51, ptr %55, align 4, !dbg !69, !tbaa !20
  store <4 x float> %52, ptr %56, align 4, !dbg !69, !tbaa !20
  %57 = add nuw i64 %16, 16
  %58 = icmp eq i64 %57, %11, !dbg !61
  br i1 %58, label %59, label %15, !dbg !61, !llvm.loop !70

59:                                               ; preds = %15
  %60 = extractelement <4 x float> %36, i64 3
  %61 = icmp eq i64 %8, %11, !dbg !61
  br i1 %61, label %66, label %62, !dbg !61

62:                                               ; preds = %5, %59
  %63 = phi float [ %7, %5 ], [ %60, %59 ]
  %64 = phi i64 [ 2, %5 ], [ %12, %59 ]
  %65 = phi i64 [ 1, %5 ], [ %13, %59 ]
  br label %67, !dbg !61

66:                                               ; preds = %67, %59, %3
  ret void, !dbg !71

67:                                               ; preds = %62, %67
  %68 = phi float [ %77, %67 ], [ %63, %62 ], !dbg !62
  %69 = phi i64 [ %80, %67 ], [ %64, %62 ]
  %70 = phi i64 [ %69, %67 ], [ %65, %62 ]
  %71 = getelementptr float, ptr %1, i64 %70, !dbg !63
  %72 = getelementptr i8, ptr %71, i64 -4, !dbg !63
  %73 = load float, ptr %72, align 4, !dbg !63, !tbaa !20
  %74 = fmul float %68, 5.000000e-01, !dbg !65
  %75 = tail call float @llvm.fmuladd.f32(float %73, float 2.500000e-01, float %74), !dbg !66
  %76 = getelementptr inbounds nuw float, ptr %1, i64 %69, !dbg !64
  %77 = load float, ptr %76, align 4, !dbg !64, !tbaa !20
  %78 = tail call float @llvm.fmuladd.f32(float %77, float 2.500000e-01, float %75), !dbg !67
  %79 = getelementptr inbounds nuw float, ptr %0, i64 %70, !dbg !68
  store float %78, ptr %79, align 4, !dbg !69, !tbaa !20
  %80 = add nuw i64 %69, 1, !dbg !72
  %81 = icmp eq i64 %80, %2, !dbg !60
  br i1 %81, label %66, label %67, !dbg !61, !llvm.loop !73
}

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: readwrite) vscale_range(1,1)
define dso_local void @matmul(ptr noalias noundef writeonly captures(none) %0, ptr noalias noundef readonly captures(none) %1, ptr noalias noundef readonly captures(none) %2, i64 noundef %3) local_unnamed_addr #0 !dbg !74 {
  %5 = icmp eq i64 %3, 0, !dbg !75
  br i1 %5, label %17, label %6, !dbg !76

6:                                                ; preds = %4
  %7 = icmp ult i64 %3, 4
  %8 = and i64 %3, -4
  %9 = icmp eq i64 %3, %8
  %10 = and i64 %3, 3
  %11 = icmp eq i64 %10, 0
  br label %12, !dbg !76

12:                                               ; preds = %6, %80
  %13 = phi i64 [ %81, %80 ], [ 0, %6 ]
  %14 = mul i64 %13, %3
  %15 = getelementptr float, ptr %1, i64 %14
  %16 = getelementptr float, ptr %0, i64 %14
  br label %18, !dbg !77

17:                                               ; preds = %80, %4
  ret void, !dbg !78

18:                                               ; preds = %12, %83
  %19 = phi i64 [ 0, %12 ], [ %86, %83 ]
  %20 = getelementptr float, ptr %2, i64 %19, !dbg !79
  br i1 %7, label %58, label %21, !dbg !79

21:                                               ; preds = %18, %21
  %22 = phi i64 [ %55, %21 ], [ 0, %18 ], !dbg !80
  %23 = phi float [ %54, %21 ], [ 0.000000e+00, %18 ]
  %24 = or disjoint i64 %22, 1
  %25 = or disjoint i64 %22, 2
  %26 = or disjoint i64 %22, 3
  %27 = getelementptr float, ptr %15, i64 %22, !dbg !81
  %28 = getelementptr float, ptr %15, i64 %24, !dbg !81
  %29 = getelementptr float, ptr %15, i64 %25, !dbg !81
  %30 = getelementptr float, ptr %15, i64 %26, !dbg !81
  %31 = load float, ptr %27, align 4, !dbg !81, !tbaa !20
  %32 = load float, ptr %28, align 4, !dbg !81, !tbaa !20
  %33 = load float, ptr %29, align 4, !dbg !81, !tbaa !20
  %34 = load float, ptr %30, align 4, !dbg !81, !tbaa !20
  %35 = mul i64 %22, %3, !dbg !82
  %36 = mul i64 %24, %3, !dbg !82
  %37 = mul i64 %25, %3, !dbg !82
  %38 = mul i64 %26, %3, !dbg !82
  %39 = getelementptr float, ptr %20, i64 %35, !dbg !83
  %40 = getelementptr float, ptr %20, i64 %36, !dbg !83
  %41 = getelementptr float, ptr %20, i64 %37, !dbg !83
  %42 = getelementptr float, ptr %20, i64 %38, !dbg !83
  %43 = load float, ptr %39, align 4, !dbg !83, !tbaa !20
  %44 = load float, ptr %40, align 4, !dbg !83, !tbaa !20
  %45 = load float, ptr %41, align 4, !dbg !83, !tbaa !20
  %46 = load float, ptr %42, align 4, !dbg !83, !tbaa !20
  %47 = fmul float %31, %43
  %48 = fmul float %32, %44
  %49 = fmul float %33, %45
  %50 = fmul float %34, %46
  %51 = fadd float %23, %47, !dbg !84
  %52 = fadd float %51, %48, !dbg !84
  %53 = fadd float %52, %49, !dbg !84
  %54 = fadd float %53, %50, !dbg !84
  %55 = add nuw i64 %22, 4, !dbg !80
  %56 = icmp eq i64 %55, %8, !dbg !79
  br i1 %56, label %57, label %21, !dbg !79, !llvm.loop !85

57:                                               ; preds = %21
  br i1 %9, label %83, label %58, !dbg !79

58:                                               ; preds = %18, %57
  %59 = phi i64 [ 0, %18 ], [ %8, %57 ]
  %60 = phi float [ 0.000000e+00, %18 ], [ %54, %57 ]
  br i1 %11, label %74, label %61, !dbg !79

61:                                               ; preds = %58, %61
  %62 = phi i64 [ %71, %61 ], [ %59, %58 ]
  %63 = phi float [ %70, %61 ], [ %60, %58 ]
  %64 = phi i64 [ %72, %61 ], [ 0, %58 ]
  %65 = getelementptr float, ptr %15, i64 %62, !dbg !81
  %66 = load float, ptr %65, align 4, !dbg !81, !tbaa !20
  %67 = mul i64 %62, %3, !dbg !82
  %68 = getelementptr float, ptr %20, i64 %67, !dbg !83
  %69 = load float, ptr %68, align 4, !dbg !83, !tbaa !20
  %70 = tail call float @llvm.fmuladd.f32(float %66, float %69, float %63), !dbg !84
  %71 = add nuw i64 %62, 1, !dbg !80
  %72 = add i64 %64, 1, !dbg !79
  %73 = icmp eq i64 %72, %10, !dbg !79
  br i1 %73, label %74, label %61, !dbg !79, !llvm.loop !86

74:                                               ; preds = %61, %58
  %75 = phi float [ poison, %58 ], [ %70, %61 ]
  %76 = phi i64 [ %59, %58 ], [ %71, %61 ]
  %77 = phi float [ %60, %58 ], [ %70, %61 ]
  %78 = sub i64 %59, %3, !dbg !79
  %79 = icmp ugt i64 %78, -4, !dbg !79
  br i1 %79, label %83, label %88, !dbg !79

80:                                               ; preds = %83
  %81 = add nuw i64 %13, 1, !dbg !88
  %82 = icmp eq i64 %81, %3, !dbg !75
  br i1 %82, label %17, label %12, !dbg !76, !llvm.loop !89

83:                                               ; preds = %74, %88, %57
  %84 = phi float [ %54, %57 ], [ %75, %74 ], [ %117, %88 ], !dbg !84
  %85 = getelementptr float, ptr %16, i64 %19, !dbg !91
  store float %84, ptr %85, align 4, !dbg !92, !tbaa !20
  %86 = add nuw i64 %19, 1, !dbg !93
  %87 = icmp eq i64 %86, %3, !dbg !94
  br i1 %87, label %80, label %18, !dbg !77, !llvm.loop !95

88:                                               ; preds = %74, %88
  %89 = phi i64 [ %118, %88 ], [ %76, %74 ]
  %90 = phi float [ %117, %88 ], [ %77, %74 ]
  %91 = getelementptr float, ptr %15, i64 %89, !dbg !81
  %92 = load float, ptr %91, align 4, !dbg !81, !tbaa !20
  %93 = mul i64 %89, %3, !dbg !82
  %94 = getelementptr float, ptr %20, i64 %93, !dbg !83
  %95 = load float, ptr %94, align 4, !dbg !83, !tbaa !20
  %96 = tail call float @llvm.fmuladd.f32(float %92, float %95, float %90), !dbg !84
  %97 = add nuw i64 %89, 1, !dbg !80
  %98 = getelementptr float, ptr %15, i64 %97, !dbg !81
  %99 = load float, ptr %98, align 4, !dbg !81, !tbaa !20
  %100 = mul i64 %97, %3, !dbg !82
  %101 = getelementptr float, ptr %20, i64 %100, !dbg !83
  %102 = load float, ptr %101, align 4, !dbg !83, !tbaa !20
  %103 = tail call float @llvm.fmuladd.f32(float %99, float %102, float %96), !dbg !84
  %104 = add nuw i64 %89, 2, !dbg !80
  %105 = getelementptr float, ptr %15, i64 %104, !dbg !81
  %106 = load float, ptr %105, align 4, !dbg !81, !tbaa !20
  %107 = mul i64 %104, %3, !dbg !82
  %108 = getelementptr float, ptr %20, i64 %107, !dbg !83
  %109 = load float, ptr %108, align 4, !dbg !83, !tbaa !20
  %110 = tail call float @llvm.fmuladd.f32(float %106, float %109, float %103), !dbg !84
  %111 = add nuw i64 %89, 3, !dbg !80
  %112 = getelementptr float, ptr %15, i64 %111, !dbg !81
  %113 = load float, ptr %112, align 4, !dbg !81, !tbaa !20
  %114 = mul i64 %111, %3, !dbg !82
  %115 = getelementptr float, ptr %20, i64 %114, !dbg !83
  %116 = load float, ptr %115, align 4, !dbg !83, !tbaa !20
  %117 = tail call float @llvm.fmuladd.f32(float %113, float %116, float %110), !dbg !84
  %118 = add nuw i64 %89, 4, !dbg !80
  %119 = icmp eq i64 %118, %3, !dbg !96
  br i1 %119, label %83, label %88, !dbg !79, !llvm.loop !97
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare <4 x float> @llvm.fmuladd.v4f32(<4 x float>, <4 x float>, <4 x float>) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.vector.reduce.fadd.nxv4f64(double, <vscale x 4 x double>) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare double @llvm.vector.reduce.fadd.nxv2f64(double, <vscale x 2 x double>) #4

attributes #0 = { nofree norecurse nosync nounwind memory(argmem: readwrite) vscale_range(1,1) "frame-pointer"="non-leaf-no-reserve" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="neoverse-v2" "target-features"="+bf16,+bti,+ccidx,+complxnum,+crc,+dit,+dotprod,+ete,+flagm,+fp-armv8,+fp16fml,+fpac,+fullfp16,+i8mm,+jsconv,+lse,+mte,+neon,+pauth,+perfmon,+predres,+rand,+ras,+rcpc,+rdm,+sb,+spe,+ssbs,+sve,+sve-bitperm,+sve2,+trbe,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a,+v9a,-fmv" }
attributes #1 = { mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nofree norecurse nosync nounwind memory(argmem: read) vscale_range(1,1) "frame-pointer"="non-leaf-no-reserve" "no-builtins" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="neoverse-v2" "target-features"="+bf16,+bti,+ccidx,+complxnum,+crc,+dit,+dotprod,+ete,+flagm,+fp-armv8,+fp16fml,+fpac,+fullfp16,+i8mm,+jsconv,+lse,+mte,+neon,+pauth,+perfmon,+predres,+rand,+ras,+rcpc,+rdm,+sb,+spe,+ssbs,+sve,+sve-bitperm,+sve2,+trbe,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a,+v9a,-fmv" }
attributes #3 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3, !4, !5, !6}
!llvm.ident = !{!7}
!llvm.errno.tbaa = !{!8}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "clang version 22.1.4 (https://github.com/msys2/MINGW-packages 42681e05ad3617c25e48a935a48eddc72a3ac7e2)", isOptimized: true, runtimeVersion: 0, emissionKind: NoDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "D:\\graceopt\\bench\\codegen/kernels.c", directory: "D:/graceopt")
!2 = !{i32 2, !"Debug Info Version", i32 3}
!3 = !{i32 1, !"wchar_size", i32 4}
!4 = !{i32 8, !"PIC Level", i32 2}
!5 = !{i32 7, !"PIE Level", i32 2}
!6 = !{i32 7, !"frame-pointer", i32 4}
!7 = !{!"clang version 22.1.4 (https://github.com/msys2/MINGW-packages 42681e05ad3617c25e48a935a48eddc72a3ac7e2)"}
!8 = !{!9, !9, i64 0}
!9 = !{!"int", !10, i64 0}
!10 = !{!"omnipotent char", !11, i64 0}
!11 = !{!"Simple C/C++ TBAA"}
!12 = distinct !DISubprogram(name: "saxpy", scope: !13, file: !13, line: 3, type: !14, scopeLine: 3, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!13 = !DIFile(filename: "D:\\graceopt\\bench\\codegen\\kernels.c", directory: "")
!14 = !DISubroutineType(types: !15)
!15 = !{}
!16 = !DILocation(line: 4, column: 24, scope: !12)
!17 = !DILocation(line: 4, column: 3, scope: !12)
!18 = !DILocation(line: 4, column: 29, scope: !12)
!19 = !DILocation(line: 4, column: 45, scope: !12)
!20 = !{!21, !21, i64 0}
!21 = !{!"float", !10, i64 0}
!22 = !DILocation(line: 4, column: 52, scope: !12)
!23 = !DILocation(line: 4, column: 50, scope: !12)
!24 = !DILocation(line: 4, column: 39, scope: !12)
!25 = distinct !{!25, !26, !27, !28}
!26 = !{!"llvm.loop.mustprogress"}
!27 = !{!"llvm.loop.isvectorized", i32 1}
!28 = !{!"llvm.loop.unroll.runtime.disable"}
!29 = !{!"branch_weights", i32 4, i32 12}
!30 = distinct !{!30, !26, !27, !28}
!31 = !DILocation(line: 5, column: 1, scope: !12)
!32 = distinct !{!32, !26, !28, !27}
!33 = distinct !DISubprogram(name: "dot", scope: !13, file: !13, line: 6, type: !14, scopeLine: 6, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!34 = !DILocation(line: 8, column: 3, scope: !33)
!35 = !DILocation(line: 8, column: 29, scope: !33)
!36 = !DILocation(line: 8, column: 49, scope: !33)
!37 = !DILocation(line: 8, column: 41, scope: !33)
!38 = !DILocation(line: 8, column: 56, scope: !33)
!39 = !DILocation(line: 8, column: 38, scope: !33)
!40 = distinct !{!40, !26, !27, !28}
!41 = !{!"branch_weights", i32 2, i32 14}
!42 = distinct !{!42, !26, !27, !28}
!43 = !DILocation(line: 0, scope: !33)
!44 = !DILocation(line: 9, column: 3, scope: !33)
!45 = !DILocation(line: 8, column: 24, scope: !33)
!46 = distinct !{!46, !26, !28, !27}
!47 = distinct !DISubprogram(name: "invariant", scope: !13, file: !13, line: 11, type: !14, scopeLine: 11, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!48 = !DILocation(line: 12, column: 24, scope: !47)
!49 = !DILocation(line: 12, column: 3, scope: !47)
!50 = !DILocation(line: 12, column: 29, scope: !47)
!51 = !DILocation(line: 12, column: 43, scope: !47)
!52 = !DILocation(line: 12, column: 48, scope: !47)
!53 = !DILocation(line: 12, column: 34, scope: !47)
!54 = !DILocation(line: 12, column: 41, scope: !47)
!55 = distinct !{!55, !26, !27, !28}
!56 = distinct !{!56, !26, !27, !28}
!57 = !DILocation(line: 13, column: 1, scope: !47)
!58 = distinct !{!58, !26, !28, !27}
!59 = distinct !DISubprogram(name: "stencil", scope: !13, file: !13, line: 14, type: !14, scopeLine: 14, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!60 = !DILocation(line: 15, column: 28, scope: !59)
!61 = !DILocation(line: 15, column: 3, scope: !59)
!62 = !DILocation(line: 16, column: 40, scope: !59)
!63 = !DILocation(line: 16, column: 22, scope: !59)
!64 = !DILocation(line: 16, column: 55, scope: !59)
!65 = !DILocation(line: 16, column: 38, scope: !59)
!66 = !DILocation(line: 16, column: 31, scope: !59)
!67 = !DILocation(line: 16, column: 45, scope: !59)
!68 = !DILocation(line: 16, column: 5, scope: !59)
!69 = !DILocation(line: 16, column: 12, scope: !59)
!70 = distinct !{!70, !26, !27, !28}
!71 = !DILocation(line: 17, column: 1, scope: !59)
!72 = !DILocation(line: 15, column: 24, scope: !59)
!73 = distinct !{!73, !26, !28, !27}
!74 = distinct !DISubprogram(name: "matmul", scope: !13, file: !13, line: 18, type: !14, scopeLine: 18, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!75 = !DILocation(line: 19, column: 24, scope: !74)
!76 = !DILocation(line: 19, column: 3, scope: !74)
!77 = !DILocation(line: 20, column: 5, scope: !74)
!78 = !DILocation(line: 25, column: 1, scope: !74)
!79 = !DILocation(line: 22, column: 7, scope: !74)
!80 = !DILocation(line: 22, column: 33, scope: !74)
!81 = !DILocation(line: 22, column: 45, scope: !74)
!82 = !DILocation(line: 22, column: 59, scope: !74)
!83 = !DILocation(line: 22, column: 56, scope: !74)
!84 = !DILocation(line: 22, column: 42, scope: !74)
!85 = distinct !{!85, !26, !27, !28}
!86 = distinct !{!86, !87}
!87 = !{!"llvm.loop.unroll.disable"}
!88 = !DILocation(line: 19, column: 29, scope: !74)
!89 = distinct !{!89, !76, !90, !26}
!90 = !DILocation(line: 24, column: 5, scope: !74)
!91 = !DILocation(line: 23, column: 7, scope: !74)
!92 = !DILocation(line: 23, column: 16, scope: !74)
!93 = !DILocation(line: 20, column: 31, scope: !74)
!94 = !DILocation(line: 20, column: 26, scope: !74)
!95 = distinct !{!95, !77, !90, !26}
!96 = !DILocation(line: 22, column: 28, scope: !74)
!97 = distinct !{!97, !79, !98, !26, !27}
!98 = !DILocation(line: 22, column: 63, scope: !74)
