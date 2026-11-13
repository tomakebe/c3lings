strlen: сначала проверьте байт [rdi + rax], и только если он не ноль — inc rax и дальше.
Например: `.Lloop: cmp byte ptr [rdi + rax], 0` / `je .Ldone` / `inc rax` / `jmp .Lloop`.
streq: в цикле `movzx ecx, byte ptr [rdi]` / `cmp cl, [rsi]` / `jne` -> 0;
если cl == 0 (обе строки закончились одновременно) -> 1; иначе `inc rdi` / `inc rsi`.
