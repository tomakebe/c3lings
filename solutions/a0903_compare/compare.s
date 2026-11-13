# =====================================================================
#  a0903 · Сравнения: ucomisd, флаги и NaN
# =====================================================================
#
#  `ucomisd a, b` (и `comisd`) сравнивает два double и выставляет флаги
#  СТРАННО — как беззнаковое целочисленное сравнение, плюс PF для NaN:
#
#      результат        ZF  PF  CF
#      a > b             0   0   0
#      a < b             0   0   1
#      a == b            1   0   0
#      unordered (NaN)   1   1   1
#
#  Поэтому после ucomisd используют БЕЗЗНАКОВЫЕ переходы:
#      ja  (a > b),  jae (a >= b),  jb (a < b),  jbe (a <= b),
#  а не jg/jl! (jg смотрит на SF и OF, которые ucomisd обнуляет.)
#  Чтобы отличить NaN, проверяют PF: `jp unordered` — ДО остальных проверок,
#  т.к. для NaN выставлены и ZF, и CF (выглядит как «меньше» и «равно» сразу).
#
#  Удобный факт: ja/jae для NaN не срабатывают (CF=1). Поэтому компиляторы
#  переписывают `a < b` как `b > a` и обходятся одним `ja` без jp.
#
#  comisd отличается от ucomisd только тем, что сигнализирует исключение
#  (флаг в MXCSR) и для «тихих» NaN. Компиляторы используют ucomisd.
#
#  Для min/max есть готовые инструкции:  minsd dst, src  /  maxsd dst, src.
#  Их семантика несимметрична: если хотя бы один операнд NaN (или оба нули
#  разного знака), возвращается ВТОРОЙ операнд (src). Так сделано, чтобы
#  совпадать с выражением (dst < src) ? dst : src.
#
#  ЗАДАЧА:
#      fcompare(a, b)  -> -1 (a<b), 0 (a==b), 1 (a>b), 2 (хотя бы один NaN)
#      clamp(x, lo, hi) = min(max(x, lo), hi)    (одна maxsd, одна minsd)
#      count_greater(a, n, t) — сколько a[i] > t (NaN не считается)
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
    jbe 3f                  # не больше (или NaN: CF=1)
    inc rax
3:
    inc rcx
2:
    cmp rcx, rsi
    jl 1b
    ret

    .section .note.GNU-stack,"",@progbits
