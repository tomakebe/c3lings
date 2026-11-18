Buffer: `sub rsp, 32`, a pointer to the end `lea rsi, [rsp + 31]`, put '\n' (10) there.
Loop: `xor edx, edx; div r8` (r8 = 10), `add dl, '0'`, `dec rsi`, `mov [rsi], dl`, while rax != 0.
Length = (rsp + 32) - rsi. Then rdi = 1, eax = 1, syscall, and `add rsp, 32` before ret.
