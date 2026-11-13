reverse: `test rsi, rsi` / `jz` выход; `lea rsi, [rdi + rsi*4 - 4]` — указатель на последний элемент.
Цикл: `cmp rdi, rsi` / `jae` выход; обмен через eax/edx; `add rdi, 4` / `sub rsi, 4`.
index_of: rax = 0; пока rax < n: `cmp [rdi + rax*8], rdx` / `je` найдено; `inc rax`.
Если вышли по концу — `mov rax, -1`.
