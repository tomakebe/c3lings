# =====================================================================
#  a1403 · Unrolling + branchless: minimum and maximum in one pass
# =====================================================================
#
#  The whole function. The naive version with branches mispredicts on
#  random data: a "new minimum" shows up less and less often, but
#  irregularly. The branchless version with cmov never mispredicts, but
#  it creates a dependency chain: each cmovl depends on the previous
#  minimum (cmp + cmov = 2 cycles per element per chain).
#
#  So split things up here too: unroll by 2 elements with TWO pairs of
#  accumulators (min0/max0 for even, min1/max1 for odd), and merge them
#  at the end. This halves the chain length per element.
#
#  (The really fast way is SIMD: pminsd/pmaxsd on 4-8 elements at a
#  time. Try it once you have the scalar version working.)
#
#  TASK: minmax(a /*rdi*/, n /*rsi*/, out_min /*rdx*/, out_max /*rcx*/),
#  n >= 1. Store the minimum in *out_min and the maximum in *out_max.
#  No conditional branches inside the loop body (the loop branch is fine).
#
    .intel_syntax noprefix
    .text
    .globl minmax
minmax:
    # TODO: the whole thing
    ret

    .section .note.GNU-stack,"",@progbits
