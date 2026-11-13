На входе rsp ≡ 8 (mod 16), а 64 кратно 16 — после `sub rsp, 64` стек всё ещё невыровнен.
Возьмите 72 (и столько же верните в конце).
Сумма: `xor ecx, ecx`, затем цикл `movsxd rdx, dword ptr [rsp + rcx*4]` / `add rax, rdx` /
`inc rcx` / `cmp rcx, 16` / `jb`.
