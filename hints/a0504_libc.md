asm_format: в начале `sub rsp, 8` (после call rsp ≡ 8 mod 16), перед call — `mov eax, 1`,
после — `add rsp, 8`.
asm_total_len: `push rbx` / `push r12` / `sub rsp, 8`; сохраните b в r12;
`call strlen@PLT` для a, результат в rbx; затем strlen(r12) и `add rax, rbx`.
