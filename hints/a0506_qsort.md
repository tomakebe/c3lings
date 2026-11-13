Компаратор: `mov rax, [rdi]` / `cmp rax, [rsi]`; если больше (jg) — вернуть -1,
если меньше (jl) — 1, иначе 0. (Или: `setl al` / `setg cl` / `sub al, cl` / `movsx eax, al`.)
Сортировка: `sub rsp, 8`, `mov edx, 8`, `lea rcx, [rip + asm_cmp_desc]`,
`call qsort@PLT`, `add rsp, 8`. rdi и rsi уже содержат a и n.
