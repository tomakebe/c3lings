mmap is number 9. Arguments: rdi = 0, rsi = len, rdx = 3, r10 = 0x22 (not rcx!), r8 = -1, r9 = 0. len arrives in rdi — move it to rsi first.
Check for an error as in a1202 (`cmp rax, -4096; ja`) and return 0.
mprotect (10) and munmap (11): the arguments are already in place, you only need `mov eax, N; syscall`.
