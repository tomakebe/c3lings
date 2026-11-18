The write number is 1: `mov eax, 1`, then `syscall`. The result will already be in rax.
write_cstr: compute the length with a `cmp byte ptr [rdi + rdx], 0` loop, then lay out the arguments: rdi = 1 (fd), rsi = the string, rdx = the length.
Careful: first move the pointer from rdi to rsi, and only then write 1 into edi.
