asm_sum_to: прибавление 1 пропускается. Достаточно убрать `cmp` и прыгать
по `jnz` — dec сам выставит ZF, когда rcx дойдёт до нуля.
asm_count_digits: `mov rax, rdi`, `mov ecx, 10`, `xor r8d, r8d`; в цикле
`xor edx, edx` / `div rcx` / `inc r8` / `test rax, rax` / `jnz`. В конце `mov rax, r8`.
