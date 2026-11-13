asm_sign: проверяйте весь rdi, а после `mov rax, -1` нужен `ret` — иначе
выполнение провалится в .Lzero.
asm_clamp: `cmp rdi, rsi` / `jl` на метку, где `mov rax, rsi` / `ret`;
затем аналогично `cmp rdi, rdx` / `jg` на метку, возвращающую rdx.
