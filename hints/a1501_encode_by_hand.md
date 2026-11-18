answer: B8 2A 00 00 00 C3. add_args and neg_arg are broken down almost byte by byte in the header.
add_r8_r9: `mov r/m64, r64` = REX.W 89 /r. The source r8 goes into the reg field (number 8 = 1000b): the low 3 bits 000 go into ModRM, the high bit is the R bit in REX: 0x48 | 0x04 = 0x4C. ModRM = 11 000 000 = C0.
`add rax, r9` — opcode 01, ModRM 11 001 000 = C8, REX is again 0x4C.
To check: assemble these instructions with mnemonics and look at `objdump -d`.
