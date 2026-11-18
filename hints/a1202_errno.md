After `syscall`: `cmp rax, -4096` and `ja` to the error branch (the unsigned comparison catches exactly [-4095, -1]).
In the error branch: `neg eax`, `mov dword ptr [rip + last_errno], eax`, `mov rax, -1`.
close is call number 3; the error branch can be shared by both functions (`jmp`/`ja` to a single label).
