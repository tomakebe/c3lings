steps: rax = n, rcx = 0 (счётчик). Цикл: `cmp rax, 1` / `je конец`;
`test rax, 1` / `jnz нечётное`; чётное: `shr rax, 1`, нечётное: `lea rax, [rax+rax*2+1]`;
затем `inc rcx` и `jmp` к началу. Ответ — rcx.
longest_below: внешний счётчик n в rsi (от 1 до limit-1), лучший n в r8,
лучшее число шагов в r9; внутренний цикл — копия steps над rax/rcx.
