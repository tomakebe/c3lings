# =====================================================================
#  a1003 · AVX2 + FMA: saxpy and vzeroupper
# =====================================================================
#
#  AVX doubled the width: registers ymm0..ymm15, 256 bits each (8 floats).
#  The lower half of ymmN is xmmN. The instructions carry a v prefix and
#  take three operands (the sources are not clobbered):
#
#      vmovups ymm0, [rdi]            8 floats from memory (no alignment)
#      vaddps  ymm0, ymm1, ymm2       ymm0 = ymm1 + ymm2
#      vbroadcastss ymm1, xmm0        all 8 elements = xmm0[0]
#      vfmadd231ps ymm0, ymm1, ymm2   ymm0 = ymm1 * ymm2 + ymm0  (FMA3)
#
#  The digits in vfmadd are operand numbers: "231" means op2*op3 + op1.
#  There are also 132 and 213. FMA rounds ONCE, so the result may differ
#  from mul+add in the last bit (here we use integers, so it's all exact).
#  FMA is a separate cpuid flag (`fma` in /proc/cpuinfo), not part of AVX2.
#
#  vzeroupper. If a function used ymm, it must execute `vzeroupper`
#  before returning — zeroing the upper halves of all ymm. Otherwise
#  legacy (non-VEX) SSE code in the caller can slow down severalfold
#  (state transitions on Intel, false dependencies on Skylake+).
#  Compilers insert vzeroupper before every ret and call.
#
#  saxpy — "single-precision a*x plus y", a BLAS classic:
#      y[i] = a * x[i] + y[i],  i = 0..n-1
#
#  Scheme: a main loop of 8 elements (ymm), then a scalar tail
#  (vfmadd231ss xmm..., or vmulss+vaddss).
#
#  TASK: write saxpy(n /*rdi*/, a /*xmm0*/, x /*rsi*/, y /*rdx*/)
#  for any n >= 0. Don't forget vzeroupper.
#
    .intel_syntax noprefix
    .text
    .globl saxpy
saxpy:
    # TODO: the whole thing
    ret

    .section .note.GNU-stack,"",@progbits
