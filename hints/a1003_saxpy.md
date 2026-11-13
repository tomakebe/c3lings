Начните с `vbroadcastss ymm1, xmm0` — a во всех 8 полях.
Основной цикл по 8: `vmovups ymm2, [rdx + rax*4]`, `vfmadd231ps ymm2, ymm1, [rsi + rax*4]`, `vmovups [rdx + rax*4], ymm2`. Условие продолжения: rax < n - 7.
Хвост — то же самое скалярно с `vmovss` и `vfmadd231ss` (xmm0 по-прежнему содержит a).
Перед `ret` — `vzeroupper`.
