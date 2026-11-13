# =====================================================================
#  a1501 · Машинный код вручную
# =====================================================================
#
#  Финальная глава — JIT: программа, которая сама порождает машинный код.
#  Для этого нужно понимать, как инструкции выглядят в байтах. Здесь
#  функции написаны не мнемониками, а директивой .byte — и их нужно
#  «собрать» руками.
#
#  Формат инструкции x86-64:
#
#    [префиксы] [REX] опкод [ModRM] [SIB] [смещение] [непосредственное]
#
#  REX = 0100WRXB (0x40..0x4F):
#      W = 1 — 64-битный размер операнда (0x48 — самый частый REX)
#      R — старший (4-й) бит номера регистра в поле ModRM.reg
#      X — старший бит индекса в SIB
#      B — старший бит ModRM.rm (или SIB.base, или регистра в опкоде)
#
#  Номера регистров: rax 0, rcx 1, rdx 2, rbx 3, rsp 4, rbp 5, rsi 6, rdi 7,
#  r8..r15 = 8..15 (младшие 3 бита — в ModRM/опкоде, 4-й — в REX).
#
#  ModRM = mod(2 бита) reg(3) rm(3):
#      mod = 11 — rm это регистр; 00/01/10 — память (без смещения / disp8 / disp32)
#      rm = 100 при mod != 11 — дальше идёт байт SIB
#  SIB = scale(2) index(3) base(3), scale: 00=1, 01=2, 10=4, 11=8
#
#  Примеры:
#      ret                     C3
#      mov eax, imm32          B8 + imm32 (little-endian): B8 2A 00 00 00 = mov eax, 42
#      mov rax, rdi            48 89 F8     (89 /r: mov r/m64, r64;
#                                            ModRM 11 111 000: reg=rdi, rm=rax)
#      neg rax                 48 F7 D8     (F7 /3: ModRM 11 011 000)
#      lea rax, [rdi + rsi]    48 8D 04 37  (8D /r; ModRM 00 000 100 -> SIB;
#                                            SIB 00 110 111: index=rsi, base=rdi)
#      add rax, rcx            48 01 C8     (01 /r: add r/m64, r64; 11 001 000)
#
#  Проверяйте себя: `objdump -d -M intel` на собранном объектнике или
#  соберите вариант с мнемониками и сравните байты:
#      echo 'lea rax, [rdi+rsi]' | as -msyntax=intel -mnaked-reg -o /tmp/x.o && objdump -d -M intel /tmp/x.o
#
#  ЗАДАЧА: замените байты в четырёх функциях.
#      answer()            — mov eax, 42; ret
#      add_args(a, b)      — lea rax, [rdi + rsi]; ret
#      neg_arg(x)          — mov rax, rdi; neg rax; ret
#      add_r8_r9(...)      — mov rax, r8; add rax, r9; ret
#                            (r8 и r9 — расширенные регистры: нужны биты REX)
#  Сейчас все они — `xor eax, eax; ret` (31 C0 C3).
#
    .intel_syntax noprefix
    .text

    .globl answer
answer:
    .byte 0x31, 0xC0, 0xC3          # TODO

    .globl add_args
add_args:
    .byte 0x31, 0xC0, 0xC3          # TODO

    .globl neg_arg
neg_arg:
    .byte 0x31, 0xC0, 0xC3          # TODO

    .globl add_r8_r9
add_r8_r9:
    .byte 0x31, 0xC0, 0xC3          # TODO

    .section .note.GNU-stack,"",@progbits
