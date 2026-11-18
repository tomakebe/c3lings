Prologue: while n > 0 and (address & 31) != 0 — `mov [rdi], esi; add rdi, 4; dec rdx`. Alignment check: `test dil, 31`.
Body: `vmovd xmm0, esi; vpbroadcastd ymm0, xmm0`, then while n >= 8: `vmovdqa [rdi], ymm0; add rdi, 32; sub rdx, 8`.
The tail is scalar again. `vzeroupper` before returning (it can go right after the body).
