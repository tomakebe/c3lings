A one-line block works too: `asm { popcnt r, x; }`.
bswap modifies its operand in place: `asm { bswapl x; }` and return x.
pext: `uint mask = 0x1111_1111; asm { pext r, x, mask; }` — the order is Intel's: destination, source, mask.
