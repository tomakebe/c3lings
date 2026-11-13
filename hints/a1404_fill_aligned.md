Пролог: пока n > 0 и (адрес & 31) != 0 — `mov [rdi], esi; add rdi, 4; dec rdx`. Проверка выравнивания: `test dil, 31`.
Тело: `vmovd xmm0, esi; vpbroadcastd ymm0, xmm0`, затем пока n >= 8: `vmovdqa [rdi], ymm0; add rdi, 32; sub rdx, 8`.
Хвост — снова скалярно. `vzeroupper` перед возвратом (можно сразу после тела).
