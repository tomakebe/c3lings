# =====================================================================
#  a0505 · Указатели на функции: косвенный call
# =====================================================================
#
#  Функция в машинном коде — просто адрес. Указатель на функцию C3
#  (`alias IntFn = fn int(int);`) передаётся как обычное 64-битное
#  целое, и вызвать его можно косвенно:
#
#      call r12            # прыгнуть по адресу из r12
#      call [rbx + 8]      # прыгнуть по адресу, лежащему в памяти
#                          # (так работают vtable и таблицы методов)
#
#  Правила те же, что для прямого call: аргументы в rdi/rsi/...,
#  результат в eax, volatile-регистры после вызова испорчены, стек
#  выровнен по 16 перед call.
#
#  Сколько значений должно пережить вызов? Для asm_apply: указатель
#  на массив, n, указатель на функцию, индекс — четыре. Для asm_fold:
#  ещё и аккумулятор. Каждому — свой callee-saved регистр (rbx,
#  r12–r15; rbp тоже можно), а значит, push в начале, pop в конце,
#  и подсчёт выравнивания:
#      число push чётное  -> нужен ещё `sub rsp, 8`;
#      число push нечётное -> стек уже выровнен.
#
#  ЗАДАЧА: напишите обе функции целиком.
#    asm_apply(a, n, f)        : a[i] = f(a[i]) для всех i
#    asm_fold(a, n, init, f)   : acc = init; acc = f(acc, a[i]) для всех i;
#                                вернуть acc (f — указатель на fn int(int, int))
#  Программа напечатает
#      [3, 15, 35, -8, 10] sum=55 max=35 abi=ok
#
    .intel_syntax noprefix
    .text

    .globl asm_apply
asm_apply:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov rbx, rdi            # a
    mov r12, rsi            # n
    mov r13, rdx            # f
    xor r14d, r14d          # i
.Lapply_loop:
    cmp r14, r12
    jae .Lapply_done
    mov edi, [rbx + r14*4]
    call r13
    mov [rbx + r14*4], eax
    inc r14
    jmp .Lapply_loop
.Lapply_done:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

    .globl asm_fold
asm_fold:
    push rbx
    push r12
    push r13
    push r14
    push r15                # 5 push: 8 + 40 = 48 — уже выровнено
    mov rbx, rdi            # a
    mov r12, rsi            # n
    mov r15d, edx           # acc
    mov r13, rcx            # f
    xor r14d, r14d          # i
.Lfold_loop:
    cmp r14, r12
    jae .Lfold_done
    mov edi, r15d
    mov esi, [rbx + r14*4]
    call r13
    mov r15d, eax
    inc r14
    jmp .Lfold_loop
.Lfold_done:
    mov eax, r15d
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

    .section .note.GNU-stack,"",@progbits
