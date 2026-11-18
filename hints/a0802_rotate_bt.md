`ror` is the mirror twin of `rol`; the count again goes through `cl`.
After `bt`/`bts`/`btr` the answer is in the CF flag. `setc al` puts it into al, `movzx eax, al` clears the upper bits.
Important: `setc` must come BEFORE any instruction that changes the flags (`xor eax, eax` clobbers CF!).
If you're completely stuck: `bts qword ptr [rdi], rsi; setc al; movzx eax, al; ret`.
