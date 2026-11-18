After `pmovmskb r8d, xmm0`: `test r8d, r8d; jz` onward; otherwise `tzcnt r8d, r8d`, `add rax, r8`, `ret`.
count_byte uses the same skeleton, but instead of searching, `popcnt r8d, r8d` and accumulate in a separate register; keep the index in, e.g., r9.
The tail is byte by byte: `cmp byte ptr [rdi + r9], dl`.
