sum: `test rdi, rdi` / `jnz .Lrec` / `xor eax, eax` / `ret`. В .Lrec: push rbx, push r12, sub rsp 8;
`mov rbx, rdi`, `mov r12, [rbx]` (value); `mov rdi, [rbx + 8]` / call / `add r12, rax`;
`mov rdi, [rbx + 16]` / call / `add rax, r12`; эпилог.
depth — то же самое, но вместо сложения: сравнить два результата, взять больший, прибавить 1.
