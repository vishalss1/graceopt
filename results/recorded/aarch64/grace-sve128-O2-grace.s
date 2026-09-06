	.file	"kernels.c"
	.text
	.globl	saxpy                           // -- Begin function saxpy
	.p2align	4
	.type	saxpy,@function
saxpy:                                  // @saxpy
// %bb.0:
                                        // kill: def $s0 killed $s0 def $q0
	cbz	x2, .LBB0_14
// %bb.1:
	cmp	x2, #4
	b.hs	.LBB0_3
// %bb.2:
	mov	x8, xzr
	b	.LBB0_12
.LBB0_3:
	cmp	x2, #16
	b.hs	.LBB0_5
// %bb.4:
	mov	x8, xzr
	b	.LBB0_9
.LBB0_5:
	and	x9, x2, #0xc
	and	x8, x2, #0xfffffffffffffff0
	add	x10, x1, #32
	add	x11, x0, #32
	and	x12, x2, #0xfffffffffffffff0
	.p2align	5, , 16
.LBB0_6:                                // =>This Inner Loop Header: Depth=1
	ldp	q1, q2, [x10, #-32]
	ldp	q5, q6, [x11, #-32]
	ldp	q3, q4, [x10], #64
	ldp	q7, q16, [x11]
	subs	x12, x12, #16
	fmla	v6.4s, v2.4s, v0.s[0]
	fmla	v16.4s, v4.4s, v0.s[0]
	fmla	v5.4s, v1.4s, v0.s[0]
	fmla	v7.4s, v3.4s, v0.s[0]
	stp	q5, q6, [x11, #-32]
	stp	q7, q16, [x11], #64
	b.ne	.LBB0_6
// %bb.7:
	cmp	x2, x8
	b.eq	.LBB0_14
// %bb.8:
	cbz	x9, .LBB0_12
.LBB0_9:
	mov	x11, x8
	and	x8, x2, #0xfffffffffffffffc
	add	x10, x0, x11, lsl #2
	sub	x9, x11, x8
	add	x11, x1, x11, lsl #2
	.p2align	5, , 16
.LBB0_10:                               // =>This Inner Loop Header: Depth=1
	ldr	q1, [x11], #16
	ldr	q2, [x10]
	adds	x9, x9, #4
	fmla	v2.4s, v1.4s, v0.s[0]
	str	q2, [x10], #16
	b.ne	.LBB0_10
// %bb.11:
	cmp	x2, x8
	b.eq	.LBB0_14
.LBB0_12:
	sub	x9, x2, x8
	add	x10, x0, x8, lsl #2
	add	x8, x1, x8, lsl #2
	.p2align	5, , 16
.LBB0_13:                               // =>This Inner Loop Header: Depth=1
	ldr	s1, [x8], #4
	ldr	s2, [x10]
	subs	x9, x9, #1
	fmadd	s1, s0, s1, s2
	str	s1, [x10], #4
	b.ne	.LBB0_13
.LBB0_14:
	ret
.Lfunc_end0:
	.size	saxpy, .Lfunc_end0-saxpy
                                        // -- End function
	.globl	dot                             // -- Begin function dot
	.p2align	4
	.type	dot,@function
dot:                                    // @dot
// %bb.0:
	movi	d0, #0000000000000000
	cbz	x2, .LBB1_14
// %bb.1:
	cmp	x2, #1
	b.ne	.LBB1_3
// %bb.2:
	mov	x8, xzr
	b	.LBB1_12
.LBB1_3:
	cmp	x2, #16
	b.hs	.LBB1_5
// %bb.4:
	mov	x8, xzr
	movi	d0, #0000000000000000
	b	.LBB1_9
.LBB1_5:
	movi	d0, #0000000000000000
	ptrue	p0.s
	ptrue	p1.d
	and	x9, x2, #0xe
	and	x8, x2, #0xfffffffffffffff0
	mov	x10, xzr
	.p2align	5, , 16
.LBB1_6:                                // =>This Inner Loop Header: Depth=1
	ld1w	{ z1.s }, p0/z, [x0, x10, lsl #2]
	ld1w	{ z17.s }, p0/z, [x1, x10, lsl #2]
	add	x11, x0, x10, lsl #2
	ldp	q2, q3, [x11, #16]
	ldr	z4, [x11, #3, mul vl]
	add	x11, x1, x10, lsl #2
	add	x10, x10, #16
	ldp	q18, q19, [x11, #16]
	ldr	z20, [x11, #3, mul vl]
	uunpklo	z7.d, z3.s
	uunpkhi	z3.d, z3.s
	uunpklo	z5.d, z1.s
	uunpklo	z21.d, z17.s
	uunpkhi	z1.d, z1.s
	uunpkhi	z17.d, z17.s
	uunpklo	z23.d, z19.s
	uunpkhi	z19.d, z19.s
	uunpklo	z6.d, z2.s
	uunpkhi	z2.d, z2.s
	fcvt	z7.d, p1/m, z7.s
	fcvt	z3.d, p1/m, z3.s
	uunpklo	z16.d, z4.s
	uunpkhi	z4.d, z4.s
	fcvt	z5.d, p1/m, z5.s
	fcvt	z21.d, p1/m, z21.s
	fcvt	z1.d, p1/m, z1.s
	fcvt	z17.d, p1/m, z17.s
	uunpklo	z22.d, z18.s
	uunpkhi	z18.d, z18.s
	fcvt	z23.d, p1/m, z23.s
	fcvt	z19.d, p1/m, z19.s
	uunpklo	z24.d, z20.s
	uunpkhi	z20.d, z20.s
	fcvt	z6.d, p1/m, z6.s
	fcvt	z2.d, p1/m, z2.s
	fcvt	z16.d, p1/m, z16.s
	fcvt	z4.d, p1/m, z4.s
	fcvt	z22.d, p1/m, z22.s
	fcvt	z18.d, p1/m, z18.s
	fcvt	z24.d, p1/m, z24.s
	fcvt	z20.d, p1/m, z20.s
	fmul	z5.d, z5.d, z21.d
	fmul	z1.d, z1.d, z17.d
	fmul	z7.d, z7.d, z23.d
	fmul	z3.d, z3.d, z19.d
	fmul	z6.d, z6.d, z22.d
	fmul	z2.d, z2.d, z18.d
	fmul	z16.d, z16.d, z24.d
	fmul	z4.d, z4.d, z20.d
	fadda	d0, p1, d0, z5.d
	fadda	d0, p1, d0, z1.d
	fadda	d0, p1, d0, z6.d
	fadda	d0, p1, d0, z2.d
	fadda	d0, p1, d0, z7.d
	fadda	d0, p1, d0, z3.d
	fadda	d0, p1, d0, z16.d
	fadda	d0, p1, d0, z4.d
	cmp	x8, x10
	b.ne	.LBB1_6
// %bb.7:
	cmp	x2, x8
	b.eq	.LBB1_14
// %bb.8:
	cbz	x9, .LBB1_12
.LBB1_9:
	mov	x11, x8
	and	x8, x2, #0xfffffffffffffffe
	ptrue	p0.d
	add	x10, x1, x11, lsl #2
	sub	x9, x11, x8
	add	x11, x0, x11, lsl #2
	.p2align	5, , 16
.LBB1_10:                               // =>This Inner Loop Header: Depth=1
	ld1w	{ z1.d }, p0/z, [x11]
	ld1w	{ z2.d }, p0/z, [x10]
	adds	x9, x9, #2
	add	x10, x10, #8
	add	x11, x11, #8
	fcvt	z1.d, p0/m, z1.s
	fcvt	z2.d, p0/m, z2.s
	fmul	z1.d, z1.d, z2.d
	fadda	d0, p0, d0, z1.d
	b.ne	.LBB1_10
// %bb.11:
	cmp	x2, x8
	b.eq	.LBB1_14
.LBB1_12:
	sub	x9, x2, x8
	add	x10, x1, x8, lsl #2
	add	x8, x0, x8, lsl #2
	.p2align	5, , 16
.LBB1_13:                               // =>This Inner Loop Header: Depth=1
	ldr	s1, [x8], #4
	ldr	s2, [x10], #4
	subs	x9, x9, #1
	fcvt	d1, s1
	fcvt	d2, s2
	fmadd	d0, d1, d2, d0
	b.ne	.LBB1_13
.LBB1_14:
                                        // kill: def $d0 killed $d0 killed $z0
	ret
.Lfunc_end1:
	.size	dot, .Lfunc_end1-dot
                                        // -- End function
	.globl	invariant                       // -- Begin function invariant
	.p2align	4
	.type	invariant,@function
invariant:                              // @invariant
// %bb.0:
	cbz	x2, .LBB2_14
// %bb.1:
	fmadd	s1, s0, s0, s1
	fmov	s2, #1.00000000
	fadd	s0, s0, s2
	fdiv	s0, s1, s0
	cmp	x2, #4
	b.hs	.LBB2_3
// %bb.2:
	mov	x8, xzr
	b	.LBB2_12
.LBB2_3:
	cmp	x2, #16
	b.hs	.LBB2_5
// %bb.4:
	mov	x8, xzr
	b	.LBB2_9
.LBB2_5:
	and	x9, x2, #0xc
	and	x8, x2, #0xfffffffffffffff0
	add	x10, x1, #32
	add	x11, x0, #32
	and	x12, x2, #0xfffffffffffffff0
	.p2align	5, , 16
.LBB2_6:                                // =>This Inner Loop Header: Depth=1
	ldp	q1, q2, [x10, #-32]
	subs	x12, x12, #16
	fmul	v2.4s, v2.4s, v0.s[0]
	fmul	v1.4s, v1.4s, v0.s[0]
	ldp	q3, q4, [x10], #64
	fmul	v3.4s, v3.4s, v0.s[0]
	fmul	v4.4s, v4.4s, v0.s[0]
	stp	q1, q2, [x11, #-32]
	stp	q3, q4, [x11], #64
	b.ne	.LBB2_6
// %bb.7:
	cmp	x2, x8
	b.eq	.LBB2_14
// %bb.8:
	cbz	x9, .LBB2_12
.LBB2_9:
	mov	x11, x8
	and	x8, x2, #0xfffffffffffffffc
	add	x10, x0, x11, lsl #2
	sub	x9, x11, x8
	add	x11, x1, x11, lsl #2
	.p2align	5, , 16
.LBB2_10:                               // =>This Inner Loop Header: Depth=1
	ldr	q1, [x11], #16
	adds	x9, x9, #4
	fmul	v1.4s, v1.4s, v0.s[0]
	str	q1, [x10], #16
	b.ne	.LBB2_10
// %bb.11:
	cmp	x2, x8
	b.eq	.LBB2_14
.LBB2_12:
	sub	x9, x2, x8
	add	x10, x0, x8, lsl #2
	add	x8, x1, x8, lsl #2
	.p2align	5, , 16
.LBB2_13:                               // =>This Inner Loop Header: Depth=1
	ldr	s1, [x8], #4
	subs	x9, x9, #1
	fmul	s1, s0, s1
	str	s1, [x10], #4
	b.ne	.LBB2_13
.LBB2_14:
	ret
.Lfunc_end2:
	.size	invariant, .Lfunc_end2-invariant
                                        // -- End function
	.globl	stencil                         // -- Begin function stencil
	.p2align	4
	.type	stencil,@function
stencil:                                // @stencil
// %bb.0:
	cmp	x2, #3
	b.lo	.LBB3_9
// %bb.1:
	ldr	s0, [x1, #4]
	sub	x10, x2, #2
	cmp	x10, #16
	b.hs	.LBB3_3
// %bb.2:
	mov	w8, #1                          // =0x1
	mov	w9, #2                          // =0x2
	b	.LBB3_7
.LBB3_3:
	and	x11, x10, #0xfffffffffffffff0
	dup	v2.4s, v0.s[0]
	movi	v0.4s, #63, lsl #24
	fmov	v1.4s, #0.25000000
	add	x12, x0, #36
	add	x13, x1, #32
	orr	x9, x11, #0x2
	orr	x8, x11, #0x1
	and	x14, x10, #0xfffffffffffffff0
	.p2align	5, , 16
.LBB3_4:                                // =>This Inner Loop Header: Depth=1
	ldur	q7, [x13, #-24]
	ldur	q16, [x13, #-8]
	ldur	q17, [x13, #8]
	subs	x14, x14, #16
	ext	v18.16b, v2.16b, v7.16b, #12
	ldur	q2, [x13, #24]
	ldp	q3, q4, [x13, #-32]
	ldp	q5, q6, [x13]
	ext	v19.16b, v7.16b, v16.16b, #12
	ext	v20.16b, v16.16b, v17.16b, #12
	add	x13, x13, #64
	fmul	v18.4s, v18.4s, v0.4s
	fmul	v19.4s, v19.4s, v0.4s
	fmul	v20.4s, v20.4s, v0.4s
	fmla	v18.4s, v1.4s, v3.4s
	fmla	v19.4s, v1.4s, v4.4s
	fmla	v20.4s, v1.4s, v5.4s
	fmla	v18.4s, v1.4s, v7.4s
	fmla	v19.4s, v1.4s, v16.4s
	fmla	v20.4s, v1.4s, v17.4s
	ext	v21.16b, v17.16b, v2.16b, #12
	fmul	v21.4s, v21.4s, v0.4s
	fmla	v21.4s, v1.4s, v6.4s
	stp	q18, q19, [x12, #-32]
	fmla	v21.4s, v1.4s, v2.4s
	stp	q20, q21, [x12], #64
	b.ne	.LBB3_4
// %bb.5:
	cmp	x10, x11
	b.eq	.LBB3_9
// %bb.6:
	mov	s0, v2.s[3]
.LBB3_7:
	fmov	s1, #0.50000000
	fmov	s2, #0.25000000
	.p2align	5, , 16
.LBB3_8:                                // =>This Inner Loop Header: Depth=1
	add	x10, x1, x8, lsl #2
	fmul	s4, s0, s1
	ldr	s0, [x1, x9, lsl #2]
	lsl	x11, x8, #2
	mov	x8, x9
	ldur	s3, [x10, #-4]
	add	x9, x9, #1
	fmadd	s3, s3, s2, s4
	fmadd	s3, s0, s2, s3
	str	s3, [x0, x11]
	cmp	x2, x9
	b.ne	.LBB3_8
.LBB3_9:
	ret
.Lfunc_end3:
	.size	stencil, .Lfunc_end3-stencil
                                        // -- End function
	.globl	matmul                          // -- Begin function matmul
	.p2align	4
	.type	matmul,@function
matmul:                                 // @matmul
// %bb.0:
	cbz	x3, .LBB4_18
// %bb.1:
	stp	x22, x21, [sp, #-32]!           // 16-byte Folded Spill
	add	x12, x3, x3, lsl #1
	and	x9, x3, #0xfffffffffffffffc
	and	x10, x3, #0x3
	lsl	x11, x3, #4
	add	x13, x1, #8
	lsl	x14, x3, #2
	lsl	x12, x12, #2
	lsl	x15, x3, #3
	stp	x20, x19, [sp, #16]             // 16-byte Folded Spill
	mov	x8, xzr
	b	.LBB4_3
	.p2align	5, , 16
.LBB4_2:                                //   in Loop: Header=BB4_3 Depth=1
	add	x8, x8, #1
	add	x13, x13, x14
	add	x1, x1, x14
	cmp	x8, x3
	b.eq	.LBB4_17
.LBB4_3:                                // =>This Loop Header: Depth=1
                                        //     Child Loop BB4_5 Depth 2
                                        //       Child Loop BB4_8 Depth 3
                                        //       Child Loop BB4_12 Depth 3
                                        //       Child Loop BB4_16 Depth 3
	mul	x17, x8, x3
	mov	x16, xzr
	mov	x18, x2
	add	x17, x0, x17, lsl #2
	b	.LBB4_5
	.p2align	5, , 16
.LBB4_4:                                //   in Loop: Header=BB4_5 Depth=2
	str	s0, [x17, x16, lsl #2]
	add	x16, x16, #1
	add	x18, x18, #4
	cmp	x16, x3
	b.eq	.LBB4_2
.LBB4_5:                                //   Parent Loop BB4_3 Depth=1
                                        // =>  This Loop Header: Depth=2
                                        //       Child Loop BB4_8 Depth 3
                                        //       Child Loop BB4_12 Depth 3
                                        //       Child Loop BB4_16 Depth 3
	cmp	x3, #4
	b.hs	.LBB4_7
// %bb.6:                               //   in Loop: Header=BB4_5 Depth=2
	mov	x4, xzr
	movi	d0, #0000000000000000
	b	.LBB4_10
	.p2align	5, , 16
.LBB4_7:                                //   in Loop: Header=BB4_5 Depth=2
	movi	d0, #0000000000000000
	and	x4, x3, #0xfffffffffffffffc
	mov	x5, x13
	mov	x6, x18
	.p2align	5, , 16
.LBB4_8:                                //   Parent Loop BB4_3 Depth=1
                                        //     Parent Loop BB4_5 Depth=2
                                        // =>    This Inner Loop Header: Depth=3
	ldp	s1, s2, [x5, #-8]
	ldr	s5, [x6]
	ldr	s6, [x6, x14]
	subs	x4, x4, #4
	fmul	s1, s1, s5
	ldp	s3, s4, [x5], #16
	ldr	s7, [x6, x15]
	ldr	s16, [x6, x12]
	fmul	s2, s2, s6
	fmul	s3, s3, s7
	fmul	s4, s4, s16
	add	x6, x6, x11
	fadd	s0, s0, s1
	fadd	s0, s0, s2
	fadd	s0, s0, s3
	fadd	s0, s0, s4
	b.ne	.LBB4_8
// %bb.9:                               //   in Loop: Header=BB4_5 Depth=2
	and	x4, x3, #0xfffffffffffffffc
	cmp	x3, x9
	b.eq	.LBB4_4
.LBB4_10:                               //   in Loop: Header=BB4_5 Depth=2
	cbz	x10, .LBB4_13
// %bb.11:                              //   in Loop: Header=BB4_5 Depth=2
	mul	x5, x14, x4
	and	x7, x3, #0x3
	mov	x6, x4
	.p2align	5, , 16
.LBB4_12:                               //   Parent Loop BB4_3 Depth=1
                                        //     Parent Loop BB4_5 Depth=2
                                        // =>    This Inner Loop Header: Depth=3
	ldr	s1, [x1, x6, lsl #2]
	ldr	s2, [x18, x5]
	add	x6, x6, #1
	add	x5, x5, x14
	subs	x7, x7, #1
	fmadd	s0, s1, s2, s0
	b.ne	.LBB4_12
	b	.LBB4_14
	.p2align	5, , 16
.LBB4_13:                               //   in Loop: Header=BB4_5 Depth=2
	mov	x6, x4
.LBB4_14:                               //   in Loop: Header=BB4_5 Depth=2
	sub	x4, x4, x3
	cmn	x4, #4
	b.hi	.LBB4_4
// %bb.15:                              //   in Loop: Header=BB4_5 Depth=2
	add	x5, x6, #3
	add	x19, x6, #2
	sub	x4, x3, x6
	mul	x7, x14, x6
	lsl	x20, x6, #2
	madd	x6, x14, x6, x14
	mul	x5, x14, x5
	mul	x19, x14, x19
	mov	x21, x18
	.p2align	5, , 16
.LBB4_16:                               //   Parent Loop BB4_3 Depth=1
                                        //     Parent Loop BB4_5 Depth=2
                                        // =>    This Inner Loop Header: Depth=3
	add	x22, x1, x20
	ldr	s1, [x21, x7]
	subs	x4, x4, #4
	add	x20, x20, #16
	ldp	s2, s3, [x22]
	fmadd	s0, s2, s1, s0
	ldr	s1, [x21, x6]
	fmadd	s0, s3, s1, s0
	ldr	s1, [x21, x19]
	ldp	s2, s3, [x22, #8]
	fmadd	s0, s2, s1, s0
	ldr	s1, [x21, x5]
	add	x21, x21, x11
	fmadd	s0, s3, s1, s0
	b.ne	.LBB4_16
	b	.LBB4_4
.LBB4_17:
	ldp	x20, x19, [sp, #16]             // 16-byte Folded Reload
	ldp	x22, x21, [sp], #32             // 16-byte Folded Reload
.LBB4_18:
	ret
.Lfunc_end4:
	.size	matmul, .Lfunc_end4-matmul
                                        // -- End function
	.ident	"clang version 22.1.4 (https://github.com/msys2/MINGW-packages 42681e05ad3617c25e48a935a48eddc72a3ac7e2)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
