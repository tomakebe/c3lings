# =====================================================================
#  a0802 · Вращения и битовые тесты: rol/ror, bt/bts/btr
# =====================================================================
#
#  Вращение (rotate) — сдвиг, при котором выдвинутые биты не пропадают,
#  а заходят с другой стороны:
#
#      rol rax, cl    — влево по кругу      (rotl в хеш-функциях, криптографии)
#      ror rax, cl    — вправо по кругу
#
#  В C3 (как и в C) отдельного оператора вращения нет: пишут
#  (x << n) | (x >> (64 - n)), и компилятор сам узнаёт идиому и ставит rol.
#  Счётчик — опять только константа или CL.
#
#  Битовые тесты:
#
#      bt  dst, i     — CF = бит i из dst
#      bts dst, i     — CF = бит i, затем бит i := 1   (test-and-set)
#      btr dst, i     — CF = бит i, затем бит i := 0   (test-and-reset)
#      btc dst, i     — CF = бит i, затем бит инвертируется
#
#  Если dst — регистр, индекс берётся по модулю 64. Но если dst —
#  ПАМЯТЬ, а индекс — регистр, процессор трактует память как БИТОВУЮ
#  СТРОКУ неограниченной длины: `bt qword ptr [rdi], rsi` при rsi = 200
#  проверит бит 200 - 192 = 8 в слове [rdi + 24]. Удобно для bitset'ов!
#  (Цена: такая форма микрокодирована, ~10 мкоп; компиляторы её избегают
#  и считают адрес слова сами: i >> 6 и i & 63.)
#
#  Результат лежит в флаге CF. Чтобы превратить флаг в число 0/1:
#
#      setc al          # al = CF   (это setcc, подробнее в главе 13)
#      movzx eax, al    # обнулить остальные биты eax
#
#  ЗАДАЧА: допишите функции, помеченные TODO.
#      rotl64(x, n), rotr64(x, n)       — вращения
#      bitset_test(set, i)              — вернуть бит i (0/1)
#      bitset_set(set, i)               — установить бит, вернуть СТАРОЕ значение
#      bitset_clear(set, i)             — сбросить бит, вернуть СТАРОЕ значение
#
    .intel_syntax noprefix
    .text

# ulong rotl64(ulong x /*rdi*/, ulong n /*rsi*/)
    .globl rotl64
rotl64:
    mov rax, rdi
    mov rcx, rsi
    rol rax, cl
    ret

# ulong rotr64(ulong x, ulong n)
    .globl rotr64
rotr64:
    mov rax, rdi
    mov rcx, rsi
    ror rax, cl
    ret

# CInt bitset_test(ulong* set /*rdi*/, ulong i /*rsi*/)
    .globl bitset_test
bitset_test:
    bt qword ptr [rdi], rsi
    setc al
    movzx eax, al
    ret

# CInt bitset_set(ulong* set, ulong i)
    .globl bitset_set
bitset_set:
    bts qword ptr [rdi], rsi
    setc al
    movzx eax, al
    ret

# CInt bitset_clear(ulong* set, ulong i)
    .globl bitset_clear
bitset_clear:
    btr qword ptr [rdi], rsi
    setc al
    movzx eax, al
    ret

    .section .note.GNU-stack,"",@progbits
