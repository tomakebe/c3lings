`write`: `scratch |= (ulong)value << scratch_bits; scratch_bits += bits; total_bits += bits;`
if `scratch_bits >= 32` - flush the low 32 bits into `words[word_count++]`, `scratch >>= 32`, `scratch_bits -= 32`.
`read` is the mirror image: if there are fewer bits than needed, load a word `(ulong)words[word_index++] << scratch_bits`;
the result is `scratch & ((1ul << bits) - 1)`, then shift scratch.
`quantize`: clamp; `(uint)math::round((x - min) / (max - min) * steps)`, where steps = `(float)((1u << bits) - 1)`.
