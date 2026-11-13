asm_area: `imul rax, rsi`.
asm_poly: `imul rax, rdi` даст x*x; `imul rax, rax, 3` — умножит на 3;
`imul rcx, rdi, 2` положит 2x в rcx (rcx можно портить свободно). Затем add и inc.
