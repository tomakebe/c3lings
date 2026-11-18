# =====================================================================
#  a1501 · Machine code by hand
# =====================================================================
#
#  The final chapter is about JIT: a program that generates machine code
#  itself. For that you need to understand what instructions look like as
#  bytes. Here the functions are written not with mnemonics but with the
#  .byte directive — and you have to "assemble" them by hand.
#
#  x86-64 instruction format:
#
#    [prefixes] [REX] opcode [ModRM] [SIB] [displacement] [immediate]
#
#  REX = 0100WRXB (0x40..0x4F):
#      W = 1 — 64-bit operand size (0x48 is the most common REX)
#      R — high (4th) bit of the register number in the ModRM.reg field
#      X — high bit of the index in SIB
#      B — high bit of ModRM.rm (or SIB.base, or a register in the opcode)
#
#  Register numbers: rax 0, rcx 1, rdx 2, rbx 3, rsp 4, rbp 5, rsi 6, rdi 7,
#  r8..r15 = 8..15 (the low 3 bits go into ModRM/the opcode, the 4th into REX).
#
#  ModRM = mod(2 bits) reg(3) rm(3):
#      mod = 11 — rm is a register; 00/01/10 — memory (no displacement / disp8 / disp32)
#      rm = 100 with mod != 11 — a SIB byte follows
#  SIB = scale(2) index(3) base(3), scale: 00=1, 01=2, 10=4, 11=8
#
#  Examples:
#      ret                     C3
#      mov eax, imm32          B8 + imm32 (little-endian): B8 2A 00 00 00 = mov eax, 42
#      mov rax, rdi            48 89 F8     (89 /r: mov r/m64, r64;
#                                            ModRM 11 111 000: reg=rdi, rm=rax)
#      neg rax                 48 F7 D8     (F7 /3: ModRM 11 011 000)
#      lea rax, [rdi + rsi]    48 8D 04 37  (8D /r; ModRM 00 000 100 -> SIB;
#                                            SIB 00 110 111: index=rsi, base=rdi)
#      add rax, rcx            48 01 C8     (01 /r: add r/m64, r64; 11 001 000)
#
#  Check yourself: run `objdump -d -M intel` on the assembled object file, or
#  assemble a version with mnemonics and compare the bytes:
#      echo 'lea rax, [rdi+rsi]' | as -msyntax=intel -mnaked-reg -o /tmp/x.o && objdump -d -M intel /tmp/x.o
#
#  TASK: replace the bytes in the four functions.
#      answer()            — mov eax, 42; ret
#      add_args(a, b)      — lea rax, [rdi + rsi]; ret
#      neg_arg(x)          — mov rax, rdi; neg rax; ret
#      add_r8_r9(...)      — mov rax, r8; add rax, r9; ret
#                            (r8 and r9 are extended registers: you need the REX bits)
#  Right now all of them are `xor eax, eax; ret` (31 C0 C3).
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
