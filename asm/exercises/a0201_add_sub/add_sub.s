# =====================================================================
#  a0201 · add, sub, neg
# =====================================================================
#
#  Арифметика x86 — двухадресная: результат пишется в первый операнд.
#
#      add rax, rsi      # rax = rax + rsi
#      sub rax, rdx      # rax = rax - rdx
#      neg rax           # rax = 0 - rax
#      inc rax / dec rax # rax += 1 / rax -= 1
#
#  Операнды должны быть одного размера (add rax, esi — ошибка). Второй
#  операнд может быть immediate (до 32 бит со знаком): `add rax, 10`.
#
#  Каждая из этих инструкций выставляет флаги в регистре RFLAGS:
#    ZF — результат ноль,         SF — старший бит результата (знак),
#    CF — беззнаковый перенос/заём, OF — знаковое переполнение.
#  На флагах построены сравнения и переходы (главы 02–03).
#
#  Важно: для процессора нет «знаковых» и «беззнаковых» add/sub —
#  в дополнительном коде это одна и та же операция над битами. Разница
#  только в том, какие флаги вы потом смотрите (CF или OF).
#
#  ЗАДАЧА:
#    asm_calc(a, b, c) = a + b - c
#    asm_neg(x)        = -x
#    asm_dist(a, b)    = b - a
#  Программа напечатает
#      calc=12 neg=-42 dist=7
#
    .intel_syntax noprefix
    .text

    .globl asm_calc
asm_calc:
    mov rax, rdi
    add rax, rsi
    add rax, rdx            # TODO: c нужно вычесть
    ret

    .globl asm_neg
asm_neg:
    mov rax, rdi
    # TODO: одна инструкция
    ret

    .globl asm_dist
asm_dist:
    mov rax, rdi
    sub rax, rsi            # TODO: порядок операндов важен
    ret

    .section .note.GNU-stack,"",@progbits
