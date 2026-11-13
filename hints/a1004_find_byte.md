После `pmovmskb r8d, xmm0`: `test r8d, r8d; jz` дальше; иначе `tzcnt r8d, r8d`, `add rax, r8`, `ret`.
count_byte — тот же каркас, но вместо поиска `popcnt r8d, r8d` и сумма в отдельном регистре; индекс держите, например, в r9.
Хвост — побайтно: `cmp byte ptr [rdi + r9], dl`.
