The arguments arrive as (msg = rdi, len = rsi), while write expects (fd = rdi, buf = rsi, len = rdx): shuffle them in the right order (first rdx = rsi, then rsi = rdi).
Then `xor edi, edi; mov eax, 231; syscall` and, to be safe, `ud2`.
