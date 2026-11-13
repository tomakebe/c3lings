# =====================================================================
#  a0901 · Плавающая точка: регистры xmm и передача аргументов
# =====================================================================
#
#  Старый сопроцессор x87 (стек st0..st7) в 64-битном коде почти не
#  используется: вся скалярная плавающая арифметика идёт через SSE —
#  16 регистров xmm0..xmm15 по 128 бит. В скалярных инструкциях
#  используется только младшая часть регистра:
#
#      суффикс ss — scalar single (float, 32 бита)
#      суффикс sd — scalar double (double, 64 бита)
#
#      movss/movsd  xmm, xmm/mem     — копирование / загрузка
#      addss/addsd  xmm, xmm/mem     — dst += src
#      subss/subsd                   — dst -= src   (ПОРЯДОК важен!)
#      mulss/mulsd, divss/divsd      — * и /
#
#  Все они двухоперандные: `subsd xmm0, xmm1` значит xmm0 = xmm0 - xmm1.
#  (В AVX есть трёхоперандные vaddsd xmm0, xmm1, xmm2 — об этом в главе 10.)
#
#  System V ABI для плавающих аргументов:
#    * float/double аргументы идут в xmm0, xmm1, ..., xmm7 — по порядку
#      СРЕДИ ПЛАВАЮЩИХ, независимо от целых аргументов;
#    * целые и указатели — как раньше: rdi, rsi, rdx, rcx, r8, r9;
#    * результат float/double возвращается в xmm0;
#    * ВСЕ регистры xmm — caller-saved (их может испортить любой вызов).
#
#  Например, у  double mix_args(long k, double x, long m, float y)
#  k -> rdi, x -> xmm0, m -> rsi, y -> xmm1.
#
#  ЗАДАЧА: исправьте функции.
#      fadd3(a, b, c)        = a + b + c
#      fsub(a, b)            = a - b
#      lerp(a, b, t)         = a + t * (b - a)       (всё — float)
#      mix_args(k, x, m, y)  = x + y   (y — float! его нужно превратить
#                              в double: cvtss2sd xmm1, xmm1)
#
    .intel_syntax noprefix
    .text

# double fadd3(double a /*xmm0*/, double b /*xmm1*/, double c /*xmm2*/)
    .globl fadd3
fadd3:
    addsd xmm0, xmm1
    # TODO: и ещё c
    ret

# double fsub(double a, double b)
    .globl fsub
fsub:
    subsd xmm1, xmm0        # TODO: что здесь вычисляется и куда кладётся результат?
    ret

# float lerp(float a /*xmm0*/, float b /*xmm1*/, float t /*xmm2*/)
    .globl lerp
lerp:
    # TODO: xmm1 = b - a, xmm1 *= t, xmm0 += xmm1  (суффиксы ss!)
    ret

# double mix_args(long k, double x, long m, float y)
    .globl mix_args
mix_args:
    addsd xmm0, xmm2        # TODO: в каком регистре на самом деле y и какого он типа?
    ret

    .section .note.GNU-stack,"",@progbits
