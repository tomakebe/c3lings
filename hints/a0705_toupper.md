toupper: eax = счётчик. Цикл: `movzx ecx, byte ptr [rdi]` / `test ecx, ecx` / `jz` конец;
проверка диапазона через lea + `cmp edx, 25` + `ja`; если буква — `sub byte ptr [rdi], 32`
и `inc eax`; затем `inc rdi`.
count_words: edx = «внутри слова» (0/1). Пробел -> edx = 0. Не пробел и edx == 0 ->
`inc rax`, edx = 1.
