# =====================================================================
#  a0801 · Сдвиги: shl, shr, sar
# =====================================================================
#
#  Сдвиг — самая дешёвая «арифметика» процессора (1 такт, несколько
#  штук за такт). Три базовых сдвига:
#
#      shl dst, k    — влево, справа приходят нули      (x * 2^k)
#      shr dst, k    — вправо, слева приходят НУЛИ      (беззнаковое x / 2^k)
#      sar dst, k    — вправо, слева копируется ЗНАКОВЫЙ бит
#                      (знаковое деление на 2^k с округлением к -inf)
#
#  Счётчик сдвига k может быть:
#    * константой:            shl rax, 3
#    * регистром CL — и только им!   shl rax, cl
#  Никакой `shl rax, rsi` не существует: если сдвиг лежит в rsi, его
#  нужно сначала положить в rcx (`mov rcx, rsi` или `mov ecx, esi`),
#  после чего использовать младший байт `cl`.
#
#  Процессор берёт счётчик по модулю 64 (для 32-битных операндов —
#  по модулю 32): `shl rax, cl` при cl = 65 сдвинет на 1. В C3 сдвиг на
#  >= ширины типа — ошибка (паника в безопасном режиме), а железо молча
#  маскирует счётчик.
#
#  Флаги: CF получает последний «выдвинутый» бит. При счётчике 0 флаги
#  не меняются вовсе — поэтому сдвиги на переменную величину для
#  процессора сложнее, чем кажутся (на Intel `shl r, cl` — это 2-3 мкоп).
#  В BMI2 есть `shlx/shrx/sarx dst, src, cnt` — счётчик в любом регистре,
#  флаги не трогаются, 1 мкоп. Подробнее — в главе asm/docs/08_bits.md.
#
#  Извлечение битового поля [pos, pos+len) классически делают так:
#      (x >> pos) & ((1 << len) - 1)
#  Маску (1 << len) - 1 тоже придётся строить сдвигом на переменную.
#  Осторожно с len = 64: 1 << 64 по модулю даёт 1 << 0, и маска станет 0.
#  В наших тестах len < 64.
#
#  ЗАДАЧА: исправьте четыре функции (каждая помечена TODO).
#      shl_var(x, n)  = x << n
#      shr_var(x, n)  = x >> n    (беззнаковый)
#      sar_var(x, n)  = x >> n    (знаковый)
#      extract_bits(x, pos, len) = (x >> pos) & ((1 << len) - 1)
#
    .intel_syntax noprefix
    .text

# ulong shl_var(ulong x /*rdi*/, ulong n /*rsi*/)
    .globl shl_var
shl_var:
    mov rax, rdi
    mov rcx, rsi
    shl rax, cl
    ret

# ulong shr_var(ulong x, ulong n)
    .globl shr_var
shr_var:
    mov rax, rdi
    mov rcx, rsi
    shr rax, cl
    ret

# long sar_var(long x, ulong n)
    .globl sar_var
sar_var:
    mov rax, rdi
    mov rcx, rsi
    sar rax, cl
    ret

# ulong extract_bits(ulong x /*rdi*/, ulong pos /*rsi*/, ulong len /*rdx*/)
    .globl extract_bits
extract_bits:
    mov rax, rdi
    mov rcx, rsi
    shr rax, cl             # rax = x >> pos
    mov r8d, 1
    mov rcx, rdx
    shl r8, cl
    dec r8                  # r8 = (1 << len) - 1
    and rax, r8
    ret

    .section .note.GNU-stack,"",@progbits
