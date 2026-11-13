asm_apply: push rbx, r12, r13, r14 (4 штуки) + `sub rsp, 8`.
rbx = a, r12 = n, r13 = f, r14 = i. Цикл: `mov edi, [rbx + r14*4]` / `call r13` /
`mov [rbx + r14*4], eax` / `inc r14`.
asm_fold: пять значений — rbx, r12, r13, r14, r15 (5 push — уже выровнено).
Перед вызовом: `mov edi, r15d` (acc), `mov esi, [rbx + r14*4]`, `call r13`, `mov r15d, eax`.
