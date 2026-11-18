rex_w: `0x48 | ((reg >> 3) << 2) | (rm >> 3)` — the R bit (weight 4) for the reg field, the B bit (weight 1) for the rm field.
pop is a copy of push with opcode 0x58. mov_imm64: the first byte is `0x48 | (r >> 3)`.
add/sub: `rex_w(src, dst)`, the opcode, `modrm_rr(src, dst)`. imul: `rex_w(dst, src)`, `0x0F, 0xAF`, `modrm_rr(dst, src)`.
Check against the table: the driver prints both the reference bytes and yours.
