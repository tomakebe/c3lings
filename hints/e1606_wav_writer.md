Little-endian: `buf[off + i] = (char)((v >> (8 * i)) & 0xFF)` для i = 0..3 (для u16 — 0..1).
`build_wav`: идите по таблице из шапки сверху вниз; data_size = samples.len * 2, block_align = channels * 2,
byte_rate = sample_rate * block_align, riff_size = 36 + data_size. Сэмпл i пишется по смещению
`HEADER_SIZE + 2 * i` как `(ushort)s`.
`parse_wav`: используйте `tag_is`, `get_u16`, `get_u32`; проверьте, что `HEADER_SIZE + data_size == data.len`,
а `frames = data_size / (channels * 2)`.
