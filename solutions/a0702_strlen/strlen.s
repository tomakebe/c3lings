# =====================================================================
#  a0702 · C-строки: strlen и сравнение
# =====================================================================
#
#  C-строка (ZString в C3) — указатель на байты, заканчивающиеся нулём.
#  Длины нигде не хранится: чтобы её узнать, надо дойти до нуля.
#  (Срезы C3 — String — устроены иначе: пара «указатель + длина»; при
#  передаче в функцию это два аргумента, ptr и len.)
#
#  Побайтовый проход:
#      cmp byte ptr [rdi + rax], 0     # сравнить байт с нулём
#      movzx ecx, byte ptr [rdi]       # прочитать байт в регистр
#      cmp cl, byte ptr [rsi]          # сравнить два байта
#
#  Классические ошибки: посчитать завершающий 0 в длину (off-by-one),
#  забыть, что пустая строка — это сразу 0, и при сравнении строк
#  разной длины остановиться на конце одной из них, не проверив, что
#  закончилась и вторая.
#
#  ЗАДАЧА:
#    asm_strlen(s)    — длина без нуля (найдите ошибку);
#    asm_streq(a, b)  — 1, если строки равны, иначе 0 (напишите сами).
#  Программа напечатает
#      len=0 12 eq=1 0 1
#
    .intel_syntax noprefix
    .text

    .globl asm_strlen
asm_strlen:
    xor eax, eax
.Lloop:
    cmp byte ptr [rdi + rax], 0
    je .Ldone
    inc rax
    jmp .Lloop
.Ldone:
    ret

    .globl asm_streq
asm_streq:
.Leq_loop:
    movzx ecx, byte ptr [rdi]
    cmp cl, [rsi]
    jne .Leq_no
    test cl, cl
    jz .Leq_yes
    inc rdi
    inc rsi
    jmp .Leq_loop
.Leq_yes:
    mov eax, 1
    ret
.Leq_no:
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
