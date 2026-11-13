# =====================================================================
#  a0805 · BMI2: pdep и pext — коды Мортона
# =====================================================================
#
#  Две самые «волшебные» битовые инструкции x86 (BMI2):
#
#      pext dst, src, mask   — parallel bit EXTRACT: берёт из src биты,
#                              стоящие на местах единиц маски, и плотно
#                              складывает их в младшие биты dst.
#      pdep dst, src, mask   — parallel bit DEPOSIT: обратное — берёт
#                              младшие биты src и раскладывает их по
#                              позициям единиц маски.
#
#      src  = 1 0 1 1 0 1 1 0           src  = . . . . . 1 0 1
#      mask = 1 1 0 0 1 0 1 0           mask = 1 1 0 0 1 0 1 0
#      pext = . . . . 1 0 1 1           pdep = 0 0 0 0 1 0 1 0  (... и т.д.)
#
#  Форма — VEX, три операнда; mask — регистр или память, src — регистр.
#
#  Код Мортона (Z-order) чередует биты координат: x0 y0 x1 y1 x2 y2 ...
#  Близкие в 2D точки оказываются близкими и в 1D — это используют в
#  quadtree, пространственных хешах, тайловых текстурах в GPU.
#  Без BMI2 это ~12 сдвигов и масок («magic bits»), с BMI2 — две
#  инструкции:
#
#      morton(x, y) = pdep(x, 0x55555555) | pdep(y, 0xAAAAAAAA)
#
#  Важно про производительность: на Intel (Haswell+) и AMD Zen 3+
#  pdep/pext — 1 мкоп, 3 такта. А на AMD Zen 1/Zen 2 они микрокодированы
#  и стоят десятки-сотни тактов в зависимости от маски! Поэтому
#  библиотеки проверяют не только cpuid, но и модель процессора.
#
#  Маску нельзя задать непосредственным операндом — сначала в регистр.
#
#  ЗАДАЧА: допишите (TODO)
#      morton_encode(x, y)   (x, y < 65536)
#      morton_decode_x(code), morton_decode_y(code)
#      gather_nibbles(x)     — из 64-битного числа собрать младшие тетрады
#                              всех 8 байтов: 0x0A0B0C0D0E0F0102 -> 0xABCDEF12
#
    .intel_syntax noprefix
    .text

# uint morton_encode(uint x /*edi*/, uint y /*esi*/)
    .globl morton_encode
morton_encode:
    mov ecx, 0x55555555
    pdep eax, edi, ecx      # биты x — на чётные позиции
    # TODO: биты y — на нечётные позиции, и объединить с eax
    ret

# uint morton_decode_x(uint code)
    .globl morton_decode_x
morton_decode_x:
    mov ecx, 0x55555555
    pdep eax, edi, ecx      # TODO: тут нужна обратная операция
    ret

# uint morton_decode_y(uint code)
    .globl morton_decode_y
morton_decode_y:
    # TODO
    xor eax, eax
    ret

# ulong gather_nibbles(ulong x)
    .globl gather_nibbles
gather_nibbles:
    # TODO: маска — младшие 4 бита каждого байта. Но порядок! 0x0A — старший байт,
    #       и он должен стать старшей тетрадой результата. Подумайте, нужен ли bswap.
    xor eax, eax
    ret

    .section .note.GNU-stack,"",@progbits
