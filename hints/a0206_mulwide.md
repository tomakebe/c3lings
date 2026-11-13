Шаблон: `mov rax, rdi` / `mul rsi` — теперь в rdx:rax всё произведение.
mulhi возвращает rdx (`mov rax, rdx`), imulhi — то же самое, но с `imul rsi`.
mul_full: после `mul rsi` всё уже на своих местах.
muldiv: сохраните c (`mov rcx, rdx`) ДО mul, затем `mul rsi` и `div rcx`.
