# =====================================================================
#  a1006 · Dot product with AVX2: multiple accumulators
# =====================================================================
#
#  The chapter finale: a complete function.
#
#      float dot_f32(float* a, float* b, long n)   = sum of a[i] * b[i]
#
#  Requirements:
#    * the main loop handles 16 elements per iteration, with TWO ymm
#      accumulators (ymm0 and ymm1) using vfmadd231ps. Why two: FMA has a
#      latency of ~4 cycles, but the processor can start 2 per cycle. With
#      one accumulator each iteration waits for the previous one (a
#      dependency chain); with two, two chains run in parallel. Details in
#      chapter 14;
#    * then, if >= 8 remain, one more step of 8;
#    * add the accumulators together, fold ymm -> xmm:
#          vextractf128 xmm2, ymm0, 1      # upper 128 bits
#          vaddps xmm0, xmm0, xmm2
#      and do the horizontal sum of 4 floats as in a1002 (vmovhlps/vshufps/vaddss);
#    * a scalar tail (vfmadd231ss);
#    * vzeroupper before ret.
#
#  The test values are small integers, so any summation order gives
#  exactly the same result.
#
#  TASK: write dot_f32(a /*rdi*/, b /*rsi*/, n /*rdx*/).
#
    .intel_syntax noprefix
    .text
    .globl dot_f32
dot_f32:
    # TODO: the whole thing
    vxorps xmm0, xmm0, xmm0
    ret

    .section .note.GNU-stack,"",@progbits
