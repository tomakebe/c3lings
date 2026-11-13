# =====================================================================
#  a0605 · Обход двоичного дерева
# =====================================================================
#
#  Структура из main.c3:
#
#      struct Node { long value; Node* left; Node* right; }
#
#  В памяти это 24 байта: value по смещению 0, left — 8, right — 16.
#  Указатель на узел — адрес первого байта, поля читаются со смещением:
#
#      mov rax, [rdi]          # n.value
#      mov rdi, [rdi + 8]      # n = n.left
#
#  Пустое поддерево — null, т.е. 0: `test rdi, rdi` / `jz`.
#
#      sum(n)   = n == null ? 0 : n.value + sum(n.left) + sum(n.right)
#      depth(n) = n == null ? 0 : 1 + max(depth(n.left), depth(n.right))
#
#  Между вызовами нужно помнить указатель на текущий узел и частичный
#  результат — два callee-saved регистра (и не забудьте про выравнивание).
#
#  Хвостовой вызов (tail call): если последнее действие функции — вызов
#  другой функции и возврат её результата, `call f` + `ret` можно
#  заменить на `jmp f` (предварительно восстановив регистры и стек).
#  Компиляторы делают это с -O2. Здесь последний вызов — не хвостовой
#  (после него ещё сложение), но подумайте, как его сделать хвостовым.
#
#  ЗАДАЧА: напишите обе функции. Программа напечатает
#      sum=69 depth=4 sub_sum=57
#
    .intel_syntax noprefix
    .text

    .globl asm_tree_sum
asm_tree_sum:
    test rdi, rdi
    jnz .Lsum_rec
    xor eax, eax
    ret
.Lsum_rec:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, [rbx]          # value
    mov rdi, [rbx + 8]
    call asm_tree_sum
    add r12, rax
    mov rdi, [rbx + 16]
    call asm_tree_sum
    add rax, r12
    add rsp, 8
    pop r12
    pop rbx
    ret

    .globl asm_tree_depth
asm_tree_depth:
    test rdi, rdi
    jnz .Ldepth_rec
    xor eax, eax
    ret
.Ldepth_rec:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov rdi, [rbx + 8]
    call asm_tree_depth
    mov r12, rax            # depth(left)
    mov rdi, [rbx + 16]
    call asm_tree_depth
    cmp rax, r12
    jae .Ldepth_max
    mov rax, r12
.Ldepth_max:
    inc rax
    add rsp, 8
    pop r12
    pop rbx
    ret

    .section .note.GNU-stack,"",@progbits
