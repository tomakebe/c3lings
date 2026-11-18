is_pow2: after `blsr rcx, rdi` check `test rcx, rcx` and `sete al` (eax is already zeroed).
lowest_bit is exactly `blsi rax, rdi`.
Loop: `tzcnt rcx, rdi` gives the index; `blsr rdi, rdi` drops that bit and sets ZF if nothing is left — you can `jnz` straight back to the start.
collect_bits: write a byte with `mov byte ptr [rsi + rax], cl`, then `inc rax`. Don't forget the x == 0 case.
