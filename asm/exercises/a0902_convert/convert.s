# =====================================================================
#  a0902 · Преобразования: cvtsi2sd, cvttsd2si, cvtsd2si
# =====================================================================
#
#      cvtsi2sd xmm, r/m64     целое -> double     (si = signed integer)
#      cvtsi2ss xmm, r/m32     целое -> float
#      cvttsd2si r64, xmm      double -> целое, Truncate (к нулю, как (long)x в C3)
#      cvtsd2si  r64, xmm      double -> целое по ТЕКУЩЕМУ режиму округления
#                              (по умолчанию — к ближайшему, при равенстве — к ЧЁТНОМУ:
#                              2.5 -> 2, 3.5 -> 4, -2.5 -> -2; «банковское» округление)
#      cvtss2sd / cvtsd2ss     float <-> double
#
#  Режим округления задаётся регистром MXCSR (биты 13-14). Его почти никто не
#  меняет; а в SSE4.1 есть roundsd с явным режимом в непосредственном операнде.
#
#  Если результат не помещается в целое (или x — NaN), cvt*2si возвращают
#  «integer indefinite» — 0x8000000000000000 (long::min). Никакого исключения.
#  Отсюда странное (long)1e300 == long::min на x86.
#
#  Ловушка: cvtsi2sd пишет только младшие 64 бита xmm, а старшие оставляет —
#  значит, зависит от старого значения регистра (ложная зависимость).
#  Компиляторы ставят перед ним `xorps xmm0, xmm0` (или pxor). Сделайте так же.
#
#  Размер целого операнда задаётся регистром: cvtsi2sd xmm0, rdi — 64 бита,
#  cvtsi2sd xmm0, edi — 32 бита. С памятью нужен явный размер:
#      cvtsi2sd xmm1, dword ptr [rdi]
#
#  ЗАДАЧА: напишите функции.
#      long_to_double(x), trunc_to_long(x), round_to_long(x)
#      average(int* a, long n) = (сумма a[i]) / n  как double  (n >= 1)
#        Суммируйте в 64-битном целом (movsxd для знакового расширения int),
#        а в конце преобразуйте сумму и n в double и поделите.
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
    cvtsd2si rax, xmm0      # TODO: этот вариант округляет, а нужно отбрасывать дробь
    ret

    .globl round_to_long
round_to_long:
    # TODO
    xor eax, eax
    ret

# double average(int* a /*rdi*/, long n /*rsi*/)
    .globl average
average:
    # TODO: целиком
    xorps xmm0, xmm0
    ret

    .section .note.GNU-stack,"",@progbits
