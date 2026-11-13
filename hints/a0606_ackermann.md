Начало: `test rdi, rdi` / `jnz` дальше / `lea rax, [rsi + 1]` / `ret`.
n == 0: `dec rdi` / `mov esi, 1` / `jmp asm_ack` (хвостовой вызов, стек не тронут).
Иначе: `push rbx` / `mov rbx, rdi` / `dec rsi` / `call asm_ack` (rdi = m всё ещё нужен
как аргумент!) / `lea rdi, [rbx - 1]` / `mov rsi, rax` / `pop rbx` / `jmp asm_ack`.
Один push — стек выровнен для call.
