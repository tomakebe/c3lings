`write`: `scratch |= (ulong)value << scratch_bits; scratch_bits += bits; total_bits += bits;`
если `scratch_bits >= 32` — сбросить младшие 32 бита в `words[word_count++]`, `scratch >>= 32`, `scratch_bits -= 32`.
`read` — зеркально: если битов меньше, чем нужно, подгрузить слово `(ulong)words[word_index++] << scratch_bits`;
результат — `scratch & ((1ul << bits) - 1)`, затем сдвинуть scratch.
`quantize`: clamp; `(uint)math::round((x - min) / (max - min) * steps)`, где steps = `(float)((1u << bits) - 1)`.
