# =====================================================================
#  a0901 · Floating point: xmm registers and argument passing
# =====================================================================
#
#  The old x87 coprocessor (the st0..st7 stack) is barely used in 64-bit
#  code: all scalar floating-point arithmetic goes through SSE —
#  16 registers xmm0..xmm15, 128 bits each. Scalar instructions use
#  only the low part of the register:
#
#      suffix ss — scalar single (float, 32 bits)
#      suffix sd — scalar double (double, 64 bits)
#
#      movss/movsd  xmm, xmm/mem     — copy / load
#      addss/addsd  xmm, xmm/mem     — dst += src
#      subss/subsd                   — dst -= src   (ORDER matters!)
#      mulss/mulsd, divss/divsd      — * and /
#
#  They are all two-operand: `subsd xmm0, xmm1` means xmm0 = xmm0 - xmm1.
#  (AVX has three-operand vaddsd xmm0, xmm1, xmm2 — more on that in chapter 10.)
#
#  System V ABI for floating-point arguments:
#    * float/double arguments go in xmm0, xmm1, ..., xmm7 — in order
#      AMONG THE FLOATING-POINT ONES, independently of integer arguments;
#    * integers and pointers — as before: rdi, rsi, rdx, rcx, r8, r9;
#    * a float/double result is returned in xmm0;
#    * ALL xmm registers are caller-saved (any call may clobber them).
#
#  For example, in  double mix_args(long k, double x, long m, float y)
#  k -> rdi, x -> xmm0, m -> rsi, y -> xmm1.
#
#  TASK: fix the functions.
#      fadd3(a, b, c)        = a + b + c
#      fsub(a, b)            = a - b
#      lerp(a, b, t)         = a + t * (b - a)       (all float)
#      mix_args(k, x, m, y)  = x + y   (y is a float! it must be turned
#                              into a double: cvtss2sd xmm1, xmm1)
#
    .intel_syntax noprefix
    .text

# double fadd3(double a /*xmm0*/, double b /*xmm1*/, double c /*xmm2*/)
    .globl fadd3
fadd3:
    addsd xmm0, xmm1
    # TODO: and c as well
    ret

# double fsub(double a, double b)
    .globl fsub
fsub:
    subsd xmm1, xmm0        # TODO: what is computed here and where does the result go?
    ret

# float lerp(float a /*xmm0*/, float b /*xmm1*/, float t /*xmm2*/)
    .globl lerp
lerp:
    # TODO: xmm1 = b - a, xmm1 *= t, xmm0 += xmm1  (ss suffixes!)
    ret

# double mix_args(long k, double x, long m, float y)
    .globl mix_args
mix_args:
    addsd xmm0, xmm2        # TODO: which register is y really in, and what is its type?
    ret

    .section .note.GNU-stack,"",@progbits
