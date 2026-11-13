При входе в функцию [rsp] — адрес возврата, 7-й аргумент — [rsp + 8], 8-й — [rsp + 16].
asm_weighted: `imul rcx, rdx, 3` / `add rax, rcx`, и так далее для rcx (4), r8 (5), r9 (6) —
только не затрите rcx до того, как используете 4-й аргумент.
asm_mixed: int'ы читаются как dword: `mov eax, [rsp + 8]` / `add eax, [rsp + 16]`.
