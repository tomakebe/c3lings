is_pow2: после `blsr rcx, rdi` проверьте `test rcx, rcx` и `sete al` (eax уже обнулён).
lowest_bit — это ровно `blsi rax, rdi`.
Цикл: `tzcnt rcx, rdi` — индекс; `blsr rdi, rdi` выбрасывает этот бит и ставит ZF, если больше ничего не осталось — можно сразу `jnz` в начало.
collect_bits: запись байта — `mov byte ptr [rsi + rax], cl`, потом `inc rax`. Не забудьте случай x == 0.
