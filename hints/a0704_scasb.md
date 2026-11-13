strlen: шаблон из шапки, в конце `mov rax, rcx`.
memchr: `test rdx, rdx` / `jz` -> null; `mov eax, esi` / `mov rcx, rdx` / `repne scasb`;
`jne` -> null (ZF = 0, не нашли). Иначе ответ — `lea rax, [rdi - 1]`
(rdi уже ушёл на байт дальше найденного).
