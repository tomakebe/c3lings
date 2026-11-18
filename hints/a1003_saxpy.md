Start with `vbroadcastss ymm1, xmm0` — a in all 8 lanes.
Main loop by 8: `vmovups ymm2, [rdx + rax*4]`, `vfmadd231ps ymm2, ymm1, [rsi + rax*4]`, `vmovups [rdx + rax*4], ymm2`. Continue condition: rax < n - 7.
The tail is the same thing in scalar form with `vmovss` and `vfmadd231ss` (xmm0 still holds a).
Before `ret` — `vzeroupper`.
