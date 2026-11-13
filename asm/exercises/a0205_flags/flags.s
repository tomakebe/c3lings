# =====================================================================
#  a0205 · Флаги: CF, OF, SF, ZF и setcc
# =====================================================================
#
#  Посмотрим на одно сложение 32-битных чисел:
#
#      0x7FFFFFFF + 1 = 0x80000000
#        беззнаково: 2147483647 + 1 = 2147483648  — всё честно, CF = 0
#        знаково:    2147483647 + 1 = -2147483648 — переполнение, OF = 1
#
#      0xFFFFFFFF + 1 = 0x00000000
#        беззнаково: 4294967295 + 1 = 0 — перенос, CF = 1
#        знаково:    -1 + 1 = 0        — всё честно, OF = 0, ZF = 1
#
#  CF — «вышли за пределы как беззнаковое», OF — «как знаковое».
#  Для вычитания CF = 1, если был заём, т.е. a < b беззнаково.
#  SF — копия старшего бита результата. ZF — результат равен нулю.
#
#  Инструкции setcc записывают 0 или 1 в 8-битный регистр по флагу:
#      setc al / setnc al   — CF          seto al / setno al — OF
#      sets al / setns al   — SF          setz al / setnz al — ZF
#  setcc пишет ТОЛЬКО байт — остальная часть eax остаётся старой.
#  Поэтому после неё: `movzx eax, al`. (Ещё вариант — обнулить eax через
#  xor ДО операции, которая ставит флаги: xor сам меняет флаги!)
#  Подробнее setcc/cmov — в главе 13.
#
#  Флаги ставит инструкция над регистрами той ширины, что вы указали:
#  add edi, esi — 32-битные флаги, add rdi, rsi — 64-битные.
#
#  ЗАДАЧА:
#    asm_add_carries(a, b)   — 1, если uint a + b не влезает в 32 бита;
#    asm_add_overflows(a, b) — 1, если int a + b переполняется;
#    asm_sub_borrows(a, b)   — 1, если uint a - b требует заёма (a < b);
#    asm_is_negative(x)      — 1, если long x < 0 (подсказка: `test rdi, rdi`
#                              ставит SF/ZF как будто вычислили rdi & rdi).
#  Образец — asm_add_carries. Программа напечатает
#      carry=1 0 overflow=1 0 borrow=1 0 negative=1 0
#
    .intel_syntax noprefix
    .text

    .globl asm_add_carries
asm_add_carries:
    add edi, esi
    setc al
    movzx eax, al
    ret

    .globl asm_add_overflows
asm_add_overflows:
    add edi, esi
    setc al                 # TODO: нужен другой флаг
    movzx eax, al
    ret

    .globl asm_sub_borrows
asm_sub_borrows:
    sub edi, esi
    seto al                 # TODO
    movzx eax, al
    ret

    .globl asm_is_negative
asm_is_negative:
    test edi, edi           # TODO: ширина
    sets al
    # TODO: чего-то не хватает
    ret

    .section .note.GNU-stack,"",@progbits
