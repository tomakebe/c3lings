# =====================================================================
#  a1001 · SIMD: упакованные операции SSE
# =====================================================================
#
#  Регистр xmm — 128 бит, то есть 4 float (или 2 double, 16 байтов,
#  8 short, 4 int, 2 long). Packed-инструкции обрабатывают все элементы
#  сразу — «одна инструкция, много данных» (SIMD):
#
#      addps xmm0, xmm1     4 сложения float за одну инструкцию
#      mulps, subps, divps, sqrtps, minps, maxps   ...
#      addpd                2 сложения double
#
#  Загрузка/сохранение 16 байтов:
#      movaps xmm, [mem]   — адрес ОБЯЗАН быть кратен 16, иначе segfault
#      movups xmm, [mem]   — любой адрес (на современных CPU так же быстро,
#                            если данные на деле выровнены)
#  Так же и операнд-память у addps/mulps: `addps xmm0, [rdi]` требует
#  выравнивания! С невыровненными данными сначала movups в регистр.
#
#  «Размножить» скаляр на все 4 элемента (broadcast) в SSE делается
#  перестановкой:  shufps xmm1, xmm1, 0   — все 4 элемента = элемент 0.
#  (В AVX есть vbroadcastss.)
#
#  ЗАДАЧА:
#      add4(dst, a, b)              — dst[0..3] = a[0..3] + b[0..3]
#      scale4(v, k)                 — v[0..3] *= k   (k в xmm0)
#      add_arrays(dst, a, b, n)     — n кратно 4; адреса НЕ выровнены
#
    .intel_syntax noprefix
    .text

# void add4(float* dst /*rdi*/, float* a /*rsi*/, float* b /*rdx*/)
    .globl add4
add4:
    movups xmm0, [rsi]
    movups xmm1, [rdx]
    addps xmm0, xmm1
    movups [rdi], xmm0
    ret

# void scale4(float* v /*rdi*/, float k /*xmm0*/)
    .globl scale4
scale4:
    movups xmm1, [rdi]
    shufps xmm0, xmm0, 0
    mulps xmm1, xmm0
    movups [rdi], xmm1
    ret

# void add_arrays(float* dst, float* a, float* b, long n /*rcx*/)
    .globl add_arrays
add_arrays:
    xor eax, eax
    jmp 2f
1:
    movups xmm0, [rsi + rax*4]
    movups xmm1, [rdx + rax*4]
    addps xmm0, xmm1
    movups [rdi + rax*4], xmm0
    add rax, 4
2:
    cmp rax, rcx
    jl 1b
    ret

    .section .note.GNU-stack,"",@progbits
