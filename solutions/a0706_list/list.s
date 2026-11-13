# =====================================================================
#  a0706 · Связный список: указатели на указатели
# =====================================================================
#
#      struct Item { int key; Item* next; long payload; }
#
#  Раскладка (проверьте себя по правилам из a0701):
#      key      @ 0   (4 байта) + 4 байта padding
#      next     @ 8
#      payload  @ 16           sizeof = 24
#
#  Обход списка — цикл «пока указатель не null»:
#
#      .Lloop:
#          test rdi, rdi
#          jz   .Lend
#          ...  [rdi + ...]
#          mov  rdi, [rdi + 8]     # p = p->next
#          jmp  .Lloop
#
#  Разворот списка на месте — классика собеседований. Три указателя:
#
#      prev = null; cur = head;
#      while (cur) { next = cur->next; cur->next = prev; prev = cur; cur = next; }
#      return prev;
#
#  В ассемблере это 3–4 регистра и ни одного обращения к памяти, кроме
#  чтения и записи поля next. Нарисуйте на бумаге стрелки до и после —
#  ошибка в порядке присваиваний теряет хвост списка.
#
#  ЗАДАЧА: напишите три функции:
#    asm_find(head, key)        — первый элемент с таким key или null;
#    asm_sum_payload(head)      — сумма payload всех элементов;
#    asm_reverse_list(head)     — развернуть список, вернуть новую голову.
#  Программа напечатает
#      [1 -> 2 -> 3 -> 4 -> 5]
#      [5 -> 4 -> 3 -> 2 -> 1]
#      found=3 sum=15000000000
#
    .intel_syntax noprefix

    .set ITEM_KEY, 0
    .set ITEM_NEXT, 8
    .set ITEM_PAYLOAD, 16

    .text

    .globl asm_find
asm_find:
.Lfind_loop:
    test rdi, rdi
    jz .Lfind_end
    cmp dword ptr [rdi + ITEM_KEY], esi
    je .Lfind_end
    mov rdi, [rdi + ITEM_NEXT]
    jmp .Lfind_loop
.Lfind_end:
    mov rax, rdi            # либо найденный элемент, либо null
    ret

    .globl asm_sum_payload
asm_sum_payload:
    xor eax, eax
.Lsum_loop:
    test rdi, rdi
    jz .Lsum_end
    add rax, [rdi + ITEM_PAYLOAD]
    mov rdi, [rdi + ITEM_NEXT]
    jmp .Lsum_loop
.Lsum_end:
    ret

    .globl asm_reverse_list
asm_reverse_list:
    xor eax, eax            # prev = null
.Lrev_loop:
    test rdi, rdi
    jz .Lrev_end
    mov rcx, [rdi + ITEM_NEXT]  # next = cur->next
    mov [rdi + ITEM_NEXT], rax  # cur->next = prev
    mov rax, rdi                # prev = cur
    mov rdi, rcx                # cur = next
    jmp .Lrev_loop
.Lrev_end:
    ret

    .section .note.GNU-stack,"",@progbits
