# =====================================================================
#  a0804 · Перебор установленных битов: blsr, blsi, tzcnt
# =====================================================================
#
#  Классические трюки с битами, у которых в BMI1 есть по инструкции:
#
#      x & (x - 1)     сбросить младший единичный бит     blsr dst, src
#      x & -x          оставить только младший бит         blsi dst, src
#      x ^ (x - 1)     маска до младшего бита включительно blsmsk dst, src
#      ~x & y                                              andn dst, x, y
#
#  blsr ставит ZF, если результат 0, а CF — если src был 0.
#  Отсюда проверка «степень двойки»: x != 0 && (x & (x-1)) == 0.
#
#  Самый полезный приём — перебрать все единичные биты маски за
#  O(количество единиц), а не за 64 итерации:
#
#      while (x != 0) {
#          i = tzcnt(x);    // индекс младшего бита
#          ...обработать i...
#          x = blsr(x);     // и выбросить его
#      }
#
#  Так перебирают компоненты в ECS по маске архетипа, свободные слоты
#  в аллокаторе, клетки шахматной доски в битбордах и т.д.
#
#  ЗАДАЧА: напишите функции (TODO).
#      is_pow2(x)                 — 1, если x степень двойки, иначе 0
#      lowest_bit(x)              — x & -x
#      sum_bit_indices(x)         — сумма индексов всех единичных битов
#      collect_bits(x, out)       — записать индексы единичных битов
#                                   (по возрастанию) в out[] байтами,
#                                   вернуть их количество
#
    .intel_syntax noprefix
    .text

# CInt is_pow2(ulong x /*rdi*/)
    .globl is_pow2
is_pow2:
    xor eax, eax
    test rdi, rdi
    jz 1f                   # 0 — не степень двойки
    blsr rcx, rdi
    test rcx, rcx
    sete al
1:
    ret

# ulong lowest_bit(ulong x)
    .globl lowest_bit
lowest_bit:
    blsi rax, rdi
    ret

# ulong sum_bit_indices(ulong x)
    .globl sum_bit_indices
sum_bit_indices:
    xor eax, eax            # сумма
    test rdi, rdi
    jz 2f
1:
    tzcnt rcx, rdi
    add rax, rcx
    blsr rdi, rdi           # ставит ZF, когда бит был последним
    jnz 1b
2:
    ret

# ulong collect_bits(ulong x /*rdi*/, char* out /*rsi*/)
    .globl collect_bits
collect_bits:
    xor eax, eax
    test rdi, rdi
    jz 2f
1:
    tzcnt rcx, rdi
    mov byte ptr [rsi + rax], cl
    inc rax
    blsr rdi, rdi
    jnz 1b
2:
    ret

    .section .note.GNU-stack,"",@progbits
