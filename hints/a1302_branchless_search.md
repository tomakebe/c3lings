count_less: r8 обнулён вне цикла; `setl r8b` + `add rax, r8` сразу после `cmp`.
lower_bound: base в rax, len в rsi. Шаг: half = len >> 1, кандидат r8 = base + half, сравнить `[rdi + r8*4 - 4]` с key, `cmovl rax, r8`, len -= half.
После цикла (len == 1) — ещё одно сравнение a[base] с key и cmov на base + 1. Не забудьте n == 0.
