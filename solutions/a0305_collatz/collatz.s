# =====================================================================
#  a0305 · Гипотеза Коллатца: вложенные циклы
# =====================================================================
#
#  Последовательность Коллатца: если n чётное — n = n / 2, иначе
#  n = 3n + 1. Повторять, пока n != 1. Сколько шагов понадобится?
#  Для 27 — 111 шагов, и по пути n поднимается до 9232.
#
#  Пара новых (но простых) приёмов:
#    * чётность:  `test rax, 1` ставит ZF = 1, если младший бит 0
#                 (число чётное), без изменения rax;
#    * n / 2:     `shr rax, 1` — логический сдвиг вправо на 1 бит
#                 (беззнаковое деление на 2 без div; подробно — глава 08);
#    * 3n + 1:    `lea rax, [rax + rax*2 + 1]` — lea вычисляет адресное
#                 выражение, но никуда не обращается к памяти; это
#                 бесплатный «умножить на 1/2/4/8 и сложить» (глава 04).
#                 Можно и через imul + inc — как больше нравится.
#
#  Вторая функция — вложенный цикл: для каждого n от 1 до limit-1
#  посчитать число шагов и запомнить n с максимумом (при равенстве —
#  меньшее n, т.е. обновлять только при строго большем числе шагов).
#  Вызывать asm_collatz_steps через call пока нельзя (это глава 05) —
#  встраивайте внутренний цикл прямо в тело. Регистров хватает:
#  rax, rcx, rdx, rsi, rdi, r8–r11 можно портить свободно.
#
#  ЗАДАЧА: напишите обе функции целиком (limit >= 2). Программа напечатает
#      steps(27)=111 steps(837799)=524 longest_below(1000)=871 longest_below(100000)=77031
#
    .intel_syntax noprefix
    .text

    .globl asm_collatz_steps
asm_collatz_steps:
    mov rax, rdi
    xor ecx, ecx
.Ls_top:
    cmp rax, 1
    je .Ls_end
    test rax, 1
    jnz .Ls_odd
    shr rax, 1
    jmp .Ls_next
.Ls_odd:
    lea rax, [rax + rax*2 + 1]
.Ls_next:
    inc rcx
    jmp .Ls_top
.Ls_end:
    mov rax, rcx
    ret

    .globl asm_longest_below
asm_longest_below:
    mov esi, 1              # n
    mov r8d, 1              # лучший n
    xor r9d, r9d            # лучшее число шагов
.Ll_outer:
    cmp rsi, rdi
    jae .Ll_end
    mov rax, rsi
    xor ecx, ecx
.Ll_inner:
    cmp rax, 1
    je .Ll_counted
    test rax, 1
    jnz .Ll_odd
    shr rax, 1
    jmp .Ll_next
.Ll_odd:
    lea rax, [rax + rax*2 + 1]
.Ll_next:
    inc rcx
    jmp .Ll_inner
.Ll_counted:
    cmp rcx, r9
    jbe .Ll_skip
    mov r9, rcx
    mov r8, rsi
.Ll_skip:
    inc rsi
    jmp .Ll_outer
.Ll_end:
    mov rax, r8
    ret

    .section .note.GNU-stack,"",@progbits
