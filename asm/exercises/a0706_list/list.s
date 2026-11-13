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
    # TODO
    xor eax, eax
    ret

    .globl asm_sum_payload
asm_sum_payload:
    # TODO
    xor eax, eax
    ret

    .globl asm_reverse_list
asm_reverse_list:
    # TODO
    mov rax, rdi
    ret

    .section .note.GNU-stack,"",@progbits
