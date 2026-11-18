# =====================================================================
#  a0903 · Comparisons: ucomisd, flags and NaN
# =====================================================================
#
#  `ucomisd a, b` (and `comisd`) compares two doubles and sets the flags
#  in an ODD way — like an unsigned integer comparison, plus PF for NaN:
#
#      result           ZF  PF  CF
#      a > b             0   0   0
#      a < b             0   0   1
#      a == b            1   0   0
#      unordered (NaN)   1   1   1
#
#  That is why UNSIGNED jumps are used after ucomisd:
#      ja  (a > b),  jae (a >= b),  jb (a < b),  jbe (a <= b),
#  not jg/jl! (jg looks at SF and OF, which ucomisd clears.)
#  To detect NaN, check PF: `jp unordered` — BEFORE the other checks,
#  because for NaN both ZF and CF are set (it looks like "less" and "equal" at once).
#
#  A handy fact: ja/jae do not fire for NaN (CF=1). So compilers rewrite
#  `a < b` as `b > a` and get by with a single `ja` and no jp.
#
#  comisd differs from ucomisd only in that it signals an exception
#  (a flag in MXCSR) for "quiet" NaNs too. Compilers use ucomisd.
#
#  For min/max there are ready-made instructions:  minsd dst, src  /  maxsd dst, src.
#  Their semantics are asymmetric: if at least one operand is NaN (or both are
#  zeros of different sign), the SECOND operand (src) is returned. This is done
#  to match the expression (dst < src) ? dst : src.
#
#  TASK:
#      fcompare(a, b)  -> -1 (a<b), 0 (a==b), 1 (a>b), 2 (at least one NaN)
#      clamp(x, lo, hi) = min(max(x, lo), hi)    (one maxsd, one minsd)
#      count_greater(a, n, t) — how many a[i] > t (NaN does not count)
#
    .intel_syntax noprefix
    .text

# CInt fcompare(double a /*xmm0*/, double b /*xmm1*/)
    .globl fcompare
fcompare:
    ucomisd xmm0, xmm1
    jp 2f
    je 3f
    jb 1f
    mov eax, 1
    ret
1:
    mov eax, -1
    ret
2:
    mov eax, 2
    ret
3:
    xor eax, eax
    ret

# double clamp(double x, double lo, double hi)
    .globl clamp
clamp:
    maxsd xmm0, xmm1
    minsd xmm0, xmm2
    ret

# long count_greater(double* a /*rdi*/, long n /*rsi*/, double t /*xmm0*/)
    .globl count_greater
count_greater:
    xor eax, eax
    xor ecx, ecx
    jmp 2f
1:
    movsd xmm1, qword ptr [rdi + rcx*8]
    ucomisd xmm1, xmm0
    jbe 3f                  # not greater (or NaN: CF=1)
    inc rax
3:
    inc rcx
2:
    cmp rcx, rsi
    jl 1b
    ret

    .section .note.GNU-stack,"",@progbits
