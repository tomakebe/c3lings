Буфер: `sub rsp, 32`, указатель на конец `lea rsi, [rsp + 31]`, туда '\n' (10).
Цикл: `xor edx, edx; div r8` (r8 = 10), `add dl, '0'`, `dec rsi`, `mov [rsi], dl`, пока rax != 0.
Длина = (rsp + 32) - rsi. Затем rdi = 1, eax = 1, syscall, и `add rsp, 32` перед ret.
