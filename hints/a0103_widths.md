Each function is solved with a single instruction.
low32: writing a 32-bit register zeroes the top by itself (`mov eax, edi`).
low8: you need to zero-extend the byte dil. sext8: sign-extend the byte dil into rax.
sext32: `movsxd` does a 32 -> 64 sign-extend.
