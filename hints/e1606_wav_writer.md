Little-endian: `buf[off + i] = (char)((v >> (8 * i)) & 0xFF)` for i = 0..3 (for u16 - 0..1).
`build_wav`: go through the table in the header from top to bottom; data_size = samples.len * 2, block_align = channels * 2,
byte_rate = sample_rate * block_align, riff_size = 36 + data_size. Sample i is written at offset
`HEADER_SIZE + 2 * i` as `(ushort)s`.
`parse_wav`: use `tag_is`, `get_u16`, `get_u32`; check that `HEADER_SIZE + data_size == data.len`,
and `frames = data_size / (channels * 2)`.
