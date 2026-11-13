# =====================================================================
#  a0402 · Проход по массиву
# =====================================================================
#
#  Два стиля обхода массива:
#
#  1) индекс:                      2) бегущий указатель:
#       xor ecx, ecx                    lea rdx, [rdi + rsi*4]   # конец
#     .L:                             .L:
#       ... [rdi + rcx*4] ...           ... [rdi] ...
#       inc rcx                         add rdi, 4
#       cmp rcx, rsi                    cmp rdi, rdx
#       jb .L                           jb .L
#
#  Сумма int'ов может не поместиться в int — копим в 64-битном rax.
#  Но тогда каждый элемент надо прочитать со ЗНАКОВЫМ расширением до
#  64 бит. Инструкции с операндом из памяти:
#
#      movsxd rdx, dword ptr [rdi + rcx*4]   # int  -> long
#      movsx  edx, word ptr  [rdi]           # short -> int
#      movzx  edx, byte ptr  [rdi]           # uchar -> int
#
#  Ошибка-ловушка: `add rax, [rdi + rcx*4]` — размер берётся из rax,
#  т.е. процессор прочтёт 8 байт = два соседних int'а сразу.
#
#  Пустой массив (n = 0) — частый край. Проверьте до входа в цикл.
#
#  ЗАДАЧА:
#    asm_sum(a, n)      — сумма n int'ов как long (найдите ошибку);
#    asm_max_elem(a, n) — максимальный элемент (n >= 1), напишите сами.
#  Программа напечатает
#      sum=4000000007 max=2000000000 max_neg=-4
#
    .intel_syntax noprefix
    .text

    .globl asm_sum
asm_sum:
    xor eax, eax
    xor ecx, ecx
    test rsi, rsi
    jz .Ldone
.Lloop:
    add rax, [rdi + rcx*4]  # TODO: прочитано 8 байт, а элемент — 4 байта со знаком
    inc rcx
    cmp rcx, rsi
    jb .Lloop
.Ldone:
    ret

    .globl asm_max_elem
asm_max_elem:
    # TODO: eax = a[0]; для i = 1..n-1: если a[i] > eax (знаково), eax = a[i]
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
