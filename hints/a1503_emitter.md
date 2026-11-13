rex_w: `0x48 | ((reg >> 3) << 2) | (rm >> 3)` — бит R (вес 4) для поля reg, бит B (вес 1) для поля rm.
pop — копия push с опкодом 0x58. mov_imm64: первый байт `0x48 | (r >> 3)`.
add/sub: `rex_w(src, dst)`, опкод, `modrm_rr(src, dst)`. imul: `rex_w(dst, src)`, `0x0F, 0xAF`, `modrm_rr(dst, src)`.
Сверяйтесь с таблицей: драйвер печатает и эталонные, и ваши байты.
