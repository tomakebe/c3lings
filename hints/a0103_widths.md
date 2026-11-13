Каждая функция решается одной инструкцией.
low32: запись в 32-битный регистр сама обнуляет верх (`mov eax, edi`).
low8: нужно zero-extend байта dil. sext8: sign-extend байта dil в rax.
sext32: sign-extend 32 -> 64 делает `movsxd`.
