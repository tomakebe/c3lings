# =====================================================================
#  a0403 · lea: адрес вместо значения
# =====================================================================
#
#  `lea` (load effective address) вычисляет адресное выражение в
#  квадратных скобках и кладёт в приёмник САМ АДРЕС, не обращаясь
#  к памяти:
#
#      mov rax, [rdi + rsi*4 + 8]    # rax = *(long*)(rdi + rsi*4 + 8)
#      lea rax, [rdi + rsi*4 + 8]    # rax =          rdi + rsi*4 + 8
#
#  В C это разница между `p[i]` и `&p[i]`.
#
#  Поскольку lea — это просто арифметика base + index*scale + disp,
#  компиляторы используют её как быстрый калькулятор:
#      lea rax, [rdi + rdi*2]       # x * 3
#      lea rax, [rdi + rdi*4]       # x * 5
#      lea rax, [rdi*8 + 5]         # x * 8 + 5  (base можно не указывать)
#      lea eax, [rdi + rsi]         # a + b в третий регистр
#  Плюсы: три операнда (не портит источники) и НЕ меняет флаги.
#  Масштаб — только 1, 2, 4, 8; x*10 = (x*5)*2 — две lea.
#
#  ЗАДАЧА: исправьте asm_addr_of (должна вернуть &base[i + 2] для int*)
#  и напишите остальные через lea, без imul:
#    asm_mul5(x) = 5x, asm_mul9_plus7(x) = 9x + 7, asm_mul10(x) = 10x.
#  Программа напечатает
#      offset=28 mul5=35 mul9_plus7=70 mul10=70
#
    .intel_syntax noprefix
    .text

    .globl asm_addr_of
asm_addr_of:
    lea rax, [rdi + rsi*4 + 8]
    ret

    .globl asm_mul5
asm_mul5:
    lea rax, [rdi + rdi*4]
    ret

    .globl asm_mul9_plus7
asm_mul9_plus7:
    lea rax, [rdi + rdi*8 + 7]
    ret

    .globl asm_mul10
asm_mul10:
    lea rax, [rdi + rdi*4]
    lea rax, [rax + rax]
    ret

    .section .note.GNU-stack,"",@progbits
