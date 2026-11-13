max: «если a < b, взять b» — `cmovl`.
abs: после `neg rax` флаг SF говорит, отрицательно ли -x; `cmovs rax, rdi` вернёт исходное x.
sign: обнулите eax и ecx ДО `test rdi, rdi`, затем `setg al`, `setl cl`, `sub eax, ecx`.
clamp: `cmp rax, rsi; cmovl rax, rsi` (не меньше lo), затем `cmp rax, rdx; cmovg rax, rdx` (не больше hi).
