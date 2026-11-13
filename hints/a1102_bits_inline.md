Однострочный блок тоже годится: `asm { popcnt r, x; }`.
bswap меняет операнд на месте: `asm { bswapl x; }` и вернуть x.
pext: `uint mask = 0x1111_1111; asm { pext r, x, mask; }` — порядок как в Intel: приёмник, источник, маска.
