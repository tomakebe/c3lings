# =====================================================================
#  a0405 · Разворот массива и линейный поиск
# =====================================================================
#
#  Пишем две функции с нуля.
#
#  asm_reverse(a, n) — развернуть массив int на месте двумя указателями:
#
#      lo = a; hi = a + n - 1;
#      while (lo < hi) { swap(*lo, *hi); lo++; hi--; }
#
#  Указатели сравниваются беззнаково (jb/jae): адреса — не знаковые
#  числа. Осторожно с n = 0: a + n - 1 окажется ДО начала массива; ничего
#  страшного, если вы проверите lo < hi до первого обмена, — но лучше
#  явно выйти при n == 0.
#
#  Обмен через два регистра (в x86 нет mov память->память):
#      mov eax, [rdi]
#      mov edx, [rsi]
#      mov [rdi], edx
#      mov [rsi], eax
#  (Есть `xchg eax, [rsi]`, но с операндом в памяти она неявно
#  атомарная, с префиксом lock, и поэтому медленная.)
#
#  asm_index_of(a, n, key) — индекс первого long, равного key, или -1.
#
#  ЗАДАЧА: напишите обе функции. Программа напечатает
#      [4, 5, 6, 7, 3, 2, 1] idx=1 -1
#
    .intel_syntax noprefix
    .text

    .globl asm_reverse
asm_reverse:
    test rsi, rsi
    jz .Lrev_done
    lea rsi, [rdi + rsi*4 - 4]
.Lrev_loop:
    cmp rdi, rsi
    jae .Lrev_done
    mov eax, [rdi]
    mov edx, [rsi]
    mov [rdi], edx
    mov [rsi], eax
    add rdi, 4
    sub rsi, 4
    jmp .Lrev_loop
.Lrev_done:
    ret

    .globl asm_index_of
asm_index_of:
    xor eax, eax
.Lidx_loop:
    cmp rax, rsi
    jae .Lidx_none
    cmp [rdi + rax*8], rdx
    je .Lidx_found
    inc rax
    jmp .Lidx_loop
.Lidx_none:
    mov rax, -1
.Lidx_found:
    ret

    .section .note.GNU-stack,"",@progbits
