count_less: r8 is zeroed outside the loop; `setl r8b` + `add rax, r8` right after the `cmp`.
lower_bound: base in rax, len in rsi. Step: half = len >> 1, candidate r8 = base + half, compare `[rdi + r8*4 - 4]` with key, `cmovl rax, r8`, len -= half.
After the loop (len == 1) — one more comparison of a[base] with key and a cmov to base + 1. Don't forget n == 0.
