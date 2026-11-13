# =====================================================================
#  a0501 · Аргументы на стеке: седьмой и дальше
# =====================================================================
#
#  Первые шесть целых аргументов — rdi, rsi, rdx, rcx, r8, r9. Если их
#  больше, остальные вызывающий кладёт в стек (справа налево, так что
#  7-й оказывается ниже всех — по меньшему адресу), а затем `call`
#  кладёт поверх адрес возврата. В момент входа в функцию:
#
#      [rsp]        адрес возврата
#      [rsp + 8]    7-й аргумент
#      [rsp + 16]   8-й аргумент
#      ...
#
#  Каждый стековый аргумент занимает 8 байт, даже если это int — но
#  для int значимы только младшие 4 байта (старшие — мусор), поэтому
#  читайте их как dword: `mov eax, [rsp + 8]`.
#
#  Эти смещения верны ТОЛЬКО пока вы не сдвинули rsp (push, sub rsp, ...).
#  После `push rbp` 7-й аргумент окажется уже в [rsp + 16]. Поэтому в
#  функциях с кадром стека к ним обращаются через [rbp + 16] (глава 06).
#
#  ЗАДАЧА:
#    asm_weighted(a..f) = a + 2b + 3c + 4d + 5e + 6f   (все в регистрах)
#    asm_eight(a..h)    = a + g * h                    (long)
#    asm_mixed(a..h)    = g + h                        (int)
#  Программа напечатает
#      weighted=91 eight=57 mixed=-2
#
    .intel_syntax noprefix
    .text

    .globl asm_weighted
asm_weighted:
    mov rax, rdi
    lea rax, [rax + rsi*2]
    lea rax, [rax + rcx*4]  # 4d (rcx ещё не испорчен)
    imul rdx, rdx, 3
    add rax, rdx            # 3c
    imul r8, r8, 5
    add rax, r8             # 5e
    imul r9, r9, 6
    add rax, r9             # 6f
    ret

    .globl asm_eight
asm_eight:
    mov rax, [rsp + 8]
    imul rax, [rsp + 16]
    add rax, rdi
    ret

    .globl asm_mixed
asm_mixed:
    mov eax, [rsp + 8]
    add eax, [rsp + 16]
    ret

    .section .note.GNU-stack,"",@progbits
