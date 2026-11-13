# =====================================================================
#  a0705 · Обработка строки на месте
# =====================================================================
#
#  Пишем две функции целиком.
#
#  asm_toupper(s) — перевести строчные латинские буквы 'a'..'z' в
#  заглавные на месте и вернуть число изменённых символов. В ASCII
#  'a' = 0x61, 'A' = 0x41: разница ровно 32 (бит 5). Остальные байты
#  (знаки, цифры, '{', '`' — соседи 'a'..'z' по таблице) не трогаем.
#
#  Проверка диапазона одним сравнением — приём, который любят
#  компиляторы:
#      lea edx, [rcx - 'a']    # edx = c - 'a'
#      cmp edx, 25             # беззнаково: c - 'a' <= 25 ?
#      ja  .Lnot_lower         # если c < 'a', разность «огромная»
#  Два условия (c >= 'a' && c <= 'z') заменились одним беззнаковым.
#  GNU as понимает символьные константы: 'a', ' ' и т.п.
#
#  Запись байта обратно: `mov [rdi], cl` или `sub byte ptr [rdi], 32`.
#
#  asm_count_words(s) — число слов, разделённых пробелами (' '). Слово
#  начинается там, где текущий символ не пробел, а предыдущий — пробел
#  или начало строки. Держите в регистре флаг «я внутри слова».
#
#  ЗАДАЧА: напишите обе функции. Программа напечатает
#      HELLO, ASM WORLD! Z{A`@[ changed=13
#      words=4
#
    .intel_syntax noprefix
    .text

    .globl asm_toupper
asm_toupper:
    xor eax, eax
.Lup_loop:
    movzx ecx, byte ptr [rdi]
    test ecx, ecx
    jz .Lup_done
    lea edx, [rcx - 'a']
    cmp edx, 25
    ja .Lup_next
    sub byte ptr [rdi], 32
    inc rax
.Lup_next:
    inc rdi
    jmp .Lup_loop
.Lup_done:
    ret

    .globl asm_count_words
asm_count_words:
    xor eax, eax
    xor edx, edx            # 1 = внутри слова
.Lw_loop:
    movzx ecx, byte ptr [rdi]
    test ecx, ecx
    jz .Lw_done
    cmp ecx, ' '
    jne .Lw_char
    xor edx, edx
    jmp .Lw_next
.Lw_char:
    test edx, edx
    jnz .Lw_next
    inc rax
    mov edx, 1
.Lw_next:
    inc rdi
    jmp .Lw_loop
.Lw_done:
    ret

    .section .note.GNU-stack,"",@progbits
