# =====================================================================
#  a0204 · Флаг переноса: 128-битная арифметика с adc/sbb
# =====================================================================
#
#  Когда беззнаковое сложение не помещается в регистр, «лишний» бит
#  уходит во флаг CF (carry). Инструкция adc складывает с его учётом:
#
#      adc rdx, rcx     # rdx = rdx + rcx + CF
#
#  Так складывают числа произвольной длины: младшие части через add,
#  все следующие — через adc. Аналогично для вычитания: sub, затем
#  sbb (subtract with borrow: a - b - CF).
#
#  Важно: между add и adc нельзя вставлять инструкции, которые меняют
#  CF (add, sub, inc… — да, inc не трогает CF, но лучше не рисковать).
#  `mov` флаги не меняет никогда — его можно.
#
#  Как System V передаёт 128-битные числа (uint128 в C3, __int128 в C):
#  парой регистров, младшая половина первой.
#      a: lo = rdi, hi = rsi
#      b: lo = rdx, hi = rcx
#      результат: lo = rax, hi = rdx
#  (Так же возвращаются структуры до 16 байт из двух целых полей.)
#
#  ЗАДАЧА: asm_add128 = a + b, asm_sub128 = a - b (по модулю 2^128).
#  Программа напечатает
#      add: hi=1 lo=0
#      sub: hi=0 lo=ffffffffffffffff
#
    .intel_syntax noprefix
    .text

    .globl asm_add128
asm_add128:
    mov rax, rdi
    add rax, rdx            # младшие половины
    mov rdx, rsi
    adc rdx, rcx
    ret

    .globl asm_sub128
asm_sub128:
    mov rax, rdi
    sub rax, rdx
    mov rdx, rsi
    sbb rdx, rcx
    ret

    .section .note.GNU-stack,"",@progbits
