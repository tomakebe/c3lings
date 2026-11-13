# =====================================================================
#  a0701 · Структуры: смещения, выравнивание, padding
# =====================================================================
#
#  Для процессора структура — просто кусок памяти, а поле — смещение
#  от её начала. Смещения вычисляет компилятор по правилам ABI:
#    * каждое поле выравнивается по своему размеру (long — по 8,
#      int — по 4, short — по 2, char — по 1);
#    * между полями вставляются байты-заполнители (padding);
#    * размер структуры округляется до кратного самому строгому
#      выравниванию её полей (чтобы в массиве каждый элемент был выровнен).
#
#      struct Rec { char tag; long value; short count; }
#
#      смещение 0:  tag        (1 байт)
#               1:  padding    (7 байт)
#               8:  value      (8 байт)
#              16:  count      (2 байта)
#              18:  padding    (6 байт)   -> sizeof = 24
#
#  Переставив поля (value, count, tag), получили бы 16 байт: порядок
#  полей влияет на размер!
#
#  В GNU as смещения удобно назвать символическими константами:
#      .set REC_VALUE, 8
#      mov rax, [rdi + REC_VALUE]
#
#  Массив структур: элемент i — по адресу base + i * 24. Масштаб 24
#  в адрес не помещается (только 1/2/4/8), так что считаем индекс:
#  i * 24 = (i * 3) * 8 — `lea rax, [rcx + rcx*2]`, потом `[rdi + rax*8]`.
#  Или просто двигаем указатель: `add rdi, 24`.
#
#  ЗАДАЧА: функции написаны так, будто полей без padding'а (0, 1, 9),
#  и массив обходится с шагом 17. Исправьте смещения и шаг.
#    asm_rec_init(r, tag, value, count) — заполнить поля;
#    asm_rec_total(r) = tag + value + count (tag беззнаковый, count знаковый);
#    asm_sum_values(arr, n) — сумма поля value у n элементов.
#  Программа напечатает
#      Rec: size=24 value@8 count@16
#      total=1000000000060 sum_values=3730
#
    .intel_syntax noprefix

    .set REC_TAG, 0
    .set REC_VALUE, 8
    .set REC_COUNT, 16
    .set REC_SIZE, 24

    .text

    .globl asm_rec_init
asm_rec_init:
    mov [rdi + REC_TAG], sil
    mov [rdi + REC_VALUE], rdx
    mov [rdi + REC_COUNT], cx
    ret

    .globl asm_rec_total
asm_rec_total:
    movzx eax, byte ptr [rdi + REC_TAG]
    add rax, [rdi + REC_VALUE]
    movsx rcx, word ptr [rdi + REC_COUNT]
    add rax, rcx
    ret

    .globl asm_sum_values
asm_sum_values:
    xor eax, eax
    test rsi, rsi
    jz .Ldone
.Lloop:
    add rax, [rdi + REC_VALUE]
    add rdi, REC_SIZE
    dec rsi
    jnz .Lloop
.Ldone:
    ret

    .section .note.GNU-stack,"",@progbits
