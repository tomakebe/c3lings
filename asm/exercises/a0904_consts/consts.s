# =====================================================================
#  a0904 · Константы в .rodata, маски знака, sqrtsd, схема Горнера
# =====================================================================
#
#  У SSE нет «непосредственных» плавающих операндов: `addsd xmm0, 1.5`
#  не существует. Константы кладут в секцию данных только для чтения и
#  адресуют относительно RIP:
#
#          .section .rodata
#          .p2align 3
#      one_half:
#          .double 0.5
#          .text
#          ...
#          mulsd xmm0, qword ptr [rip + one_half]
#
#  (Можно ещё собрать константу в целом регистре и перебросить:
#   mov rax, 0x3FE0000000000000; movq xmm1, rax.)
#
#  Модуль и смена знака делаются битовыми операциями над знаковым битом
#  (бит 63 для double):
#      fabs:  andpd xmm0, [маска 0x7FFFFFFFFFFFFFFF]
#      fneg:  xorpd xmm0, [маска 0x8000000000000000]
#  andpd/xorpd — «упакованные» (packed) инструкции, они работают со всеми
#  128 битами, и их операнд в памяти ДОЛЖЕН быть выровнен на 16 байт
#  (иначе — segfault). Поэтому маску кладут как 16-байтную константу с
#  .p2align 4. Именно так делают GCC и Clang.
#
#  sqrtsd xmm0, xmm1 — корень, корректно округлённый (IEEE 754).
#
#  Схема Горнера: p(x) = c0 + c1 x + c2 x^2 + ... + c_{n-1} x^{n-1}
#      acc = c[n-1]; for i = n-2 downto 0: acc = acc * x + c[i]
#
#  ЗАДАЧА: напишите функции.
#      asm_fabs(x), asm_fneg(x)   — через маски из .rodata (см. ниже)
#      vec2_length(x, y)          = sqrt(x*x + y*y)
#      horner(c, n, x)            (n >= 1)
#      circle_area(r)             = pi * r * r; pi — константа в .rodata
#                                   (.double 3.141592653589793)
#
    .intel_syntax noprefix
    .section .rodata
    .p2align 4
abs_mask:
    .quad 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
sign_mask:
    .quad 0x8000000000000000, 0x8000000000000000
    # TODO: добавьте константу pi

    .text

    .globl asm_fabs
asm_fabs:
    # TODO: andpd с abs_mask
    ret

    .globl asm_fneg
asm_fneg:
    # TODO: xorpd с sign_mask
    ret

# double vec2_length(double x /*xmm0*/, double y /*xmm1*/)
    .globl vec2_length
vec2_length:
    # TODO
    ret

# double horner(double* c /*rdi*/, long n /*rsi*/, double x /*xmm0*/)
    .globl horner
horner:
    # TODO
    ret

    .globl circle_area
circle_area:
    # TODO
    ret

    .section .note.GNU-stack,"",@progbits
