max: "if a < b, take b" — `cmovl`.
abs: after `neg rax`, the SF flag tells whether -x is negative; `cmovs rax, rdi` returns the original x.
sign: zero eax and ecx BEFORE `test rdi, rdi`, then `setg al`, `setl cl`, `sub eax, ecx`.
clamp: `cmp rax, rsi; cmovl rax, rsi` (no less than lo), then `cmp rax, rdx; cmovg rax, rdx` (no greater than hi).
