Argument register order: rdi, rsi, rdx, rcx, r8, r9.
The second argument is rsi, the fourth is rcx, the sixth is r9.
For a 64-bit `long` write the whole of rax (`mov rax, r9`), not eax:
writing eax zeroes the upper 32 bits and truncates large/negative numbers.
