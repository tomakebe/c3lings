mulq кладёт младшую половину в rax, старшую — в rdx.
muldiv: после `mulq b` в rdx:rax лежит 128-битное произведение — ровно то, что ждёт `divq c`. Частное — в $rax.
rdtsc: `rdtsc; movl lo, $eax; movl hi, $edx;` — переменные должны быть 32-битными (uint), раз суффикс l.
