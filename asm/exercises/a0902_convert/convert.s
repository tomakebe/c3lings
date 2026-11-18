# =====================================================================
#  a0902 · Conversions: cvtsi2sd, cvttsd2si, cvtsd2si
# =====================================================================
#
#      cvtsi2sd xmm, r/m64     integer -> double     (si = signed integer)
#      cvtsi2ss xmm, r/m32     integer -> float
#      cvttsd2si r64, xmm      double -> integer, Truncate (toward zero, like (long)x in C3)
#      cvtsd2si  r64, xmm      double -> integer using the CURRENT rounding mode
#                              (by default: to nearest, ties to EVEN:
#                              2.5 -> 2, 3.5 -> 4, -2.5 -> -2; "banker's" rounding)
#      cvtss2sd / cvtsd2ss     float <-> double
#
#  The rounding mode is set by the MXCSR register (bits 13-14). Almost nobody
#  changes it; and SSE4.1 has roundsd with an explicit mode in the immediate.
#
#  If the result does not fit in an integer (or x is NaN), cvt*2si return the
#  "integer indefinite" value 0x8000000000000000 (long::min). No exception.
#  Hence the odd (long)1e300 == long::min on x86.
#
#  Trap: cvtsi2sd writes only the low 64 bits of xmm and keeps the upper ones —
#  so it depends on the register's old value (a false dependency).
#  Compilers put `xorps xmm0, xmm0` (or pxor) in front of it. Do the same.
#
#  The integer operand size is given by the register: cvtsi2sd xmm0, rdi is 64 bits,
#  cvtsi2sd xmm0, edi is 32 bits. With memory you need an explicit size:
#      cvtsi2sd xmm1, dword ptr [rdi]
#
#  TASK: write the functions.
#      long_to_double(x), trunc_to_long(x), round_to_long(x)
#      average(int* a, long n) = (sum of a[i]) / n  as a double  (n >= 1)
#        Sum in a 64-bit integer (movsxd to sign-extend the int),
#        and at the end convert the sum and n to double and divide.
#
    .intel_syntax noprefix
    .text

    .globl long_to_double
long_to_double:
    xorps xmm0, xmm0
    # TODO
    ret

    .globl trunc_to_long
trunc_to_long:
    cvtsd2si rax, xmm0      # TODO: this variant rounds, but we need to drop the fraction
    ret

    .globl round_to_long
round_to_long:
    # TODO
    xor eax, eax
    ret

# double average(int* a /*rdi*/, long n /*rsi*/)
    .globl average
average:
    # TODO: the whole thing
    xorps xmm0, xmm0
    ret

    .section .note.GNU-stack,"",@progbits
