In an `asm { }` block the destination is the FIRST operand, as in Intel syntax: `addl r, b` means r += b.
For 64-bit variables use the q suffix: `subq r, b`.
To add one: `incl r;`.
