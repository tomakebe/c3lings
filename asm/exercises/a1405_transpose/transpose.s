# =====================================================================
#  a1405 · Transposition: SIMD shuffles and memory access
# =====================================================================
#
#  A naive transpose dst[c][r] = src[r][c] reads src by rows but writes
#  dst by columns — with a stride of n*4 bytes. Every store lands in a
#  new cache line; with n = 1024 the lines evict each other (cache
#  associativity, "4K aliasing"). The classic fix is blocking: transpose
#  the matrix in 4x4 (or 8x8) tiles, using SIMD registers inside a tile.
#
#  Transposing a 4x4 int tile in registers (same as _MM_TRANSPOSE4_PS):
#
#      x0 = a0 a1 a2 a3       t0 = punpckldq(x0, x1) = a0 b0 a1 b1
#      x1 = b0 b1 b2 b3       t1 = punpckhdq(x0, x1) = a2 b2 a3 b3
#      x2 = c0 c1 c2 c3       t2 = punpckldq(x2, x3) = c0 d0 c1 d1
#      x3 = d0 d1 d2 d3       t3 = punpckhdq(x2, x3) = c2 d2 c3 d3
#
#      r0 = punpcklqdq(t0, t2) = a0 b0 c0 d0
#      r1 = punpckhqdq(t0, t2) = a1 b1 c1 d1
#      r2 = punpcklqdq(t1, t3) = a2 b2 c2 d2
#      r3 = punpckhqdq(t1, t3) = a3 b3 c3 d3
#
#  (The instructions are two-operand: punpckldq x, y puts the result in
#   x, so copy first with movdqa t, x.)
#
#  Strides are in int ELEMENTS; in bytes that is stride*4.
#  For the full matrix, block (bi, bj) of src is copied transposed into
#  block (bj, bi) of dst. For large matrices one adds prefetcht0 of the
#  next block's rows and walks the blocks in "strips" so the working set
#  fits in L1.
#
#  TASK:
#      transpose4x4(dst, dst_stride, src, src_stride) — one block
#      transpose(dst, src, n)  — n is a multiple of 4; call transpose4x4
#                                (don't forget about callee-saved registers
#                                 and stack alignment before call!)
#
    .intel_syntax noprefix
    .text

# void transpose4x4(int* dst /*rdi*/, long dst_stride /*rsi*/, int* src /*rdx*/, long src_stride /*rcx*/)
    .globl transpose4x4
transpose4x4:
    shl rsi, 2              # strides in bytes
    shl rcx, 2
    movdqu xmm0, [rdx]
    movdqu xmm1, [rdx + rcx]
    movdqu xmm2, [rdx + rcx*2]
    add rdx, rcx
    movdqu xmm3, [rdx + rcx*2]
    # TODO: shuffles and storing the four rows to dst
    ret

# void transpose(int* dst /*rdi*/, int* src /*rsi*/, long n /*rdx*/)
    .globl transpose
transpose:
    # TODO: two nested loops over the blocks
    ret

    .section .note.GNU-stack,"",@progbits
