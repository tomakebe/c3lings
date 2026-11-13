# =====================================================================
#  a0401 · Память: [base + index*scale + disp]
# =====================================================================
#
#  Квадратные скобки — обращение к памяти. Общая форма адреса:
#
#      [base + index*scale + disp]
#        base, index — регистры; scale — 1, 2, 4 или 8; disp — число
#
#      mov eax, [rdi]            # eax = *(int*)rdi   (4 байта, т.к. eax)
#      mov eax, [rdi + 8]        # третий int: смещение 2 * 4 = 8
#      mov eax, [rdi + rsi*4]    # a[i] для int (sizeof = 4)
#      mov rax, [rdi + rsi*8]    # a[i] для long (sizeof = 8)
#      mov [rdi + rsi*4], edx    # a[i] = edx  (запись)
#
#  Размер операции определяется регистром. Если регистра нет
#  (`mov [rdi], 5`), ассемблер не знает, сколько байт писать — нужно
#  уточнить: `mov dword ptr [rdi], 5` (byte/word/dword/qword ptr).
#
#  Масштаб (scale) — это sizeof элемента. Ассемблер не знает типов:
#  указатель — просто число, и «a + i» в байтах — ваша забота. Именно
#  здесь начинающие чаще всего ошибаются.
#
#  Индекс — знаковый long, поэтому отрицательный индекс корректно
#  указывает «назад» от base.
#
#  ЗАДАЧА:
#    asm_get(a, i)      = a[i]  для int* a
#    asm_set(a, i, v)   : a[i] = v  для int* a, v — int (в edx)
#    asm_get_long(a, i) = a[i]  для long* a
#  Программа напечатает
#      a[2]=30 a[3]=-40 b[2]=300000000000 after set: [10, 20, 30, -40, 555, 60]
#
    .intel_syntax noprefix
    .text

    .globl asm_get
asm_get:
    mov eax, [rdi + rsi]    # TODO: масштаб
    ret

    .globl asm_set
asm_set:
    mov [rdi + rsi*4], rdx  # TODO: сколько байт мы пишем?
    ret

    .globl asm_get_long
asm_get_long:
    mov eax, [rdi + rsi*4]  # TODO
    ret

    .section .note.GNU-stack,"",@progbits
