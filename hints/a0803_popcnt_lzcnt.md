`popcnt rax, rdi` and `tzcnt rax, rdi` — one instruction each.
log2: the index of the highest bit = 63 - lzcnt(x). Compute lzcnt into rcx, put 63 into rax and subtract.
next_pow2: x - 1 is conveniently computed with `lea rax, [rdi - 1]`; then lzcnt, then 64 - n into `cl`, then `shl` a one.
Trick: the shift count is taken modulo 64, so `neg ecx` already gives the needed count 64 - n.
