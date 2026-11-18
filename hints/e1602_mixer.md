`pan_gains`: angle `(pan + 1) * PI / 4`, left is `math::cos`, right is `math::sin` (don't forget to cast PI to float).
`mix_voice`: for each frame f first check `v.pos >= v.samples.len` - either `pos = 0` (looping),
or `active = false` and return. Then `s = samples[pos++] * gain`, `out[2f] += s*gl`, `out[2f+1] += s*gr`.
Note: we add (`+=`), not assign - otherwise voices overwrite each other.
`to_s16_master`: y = x * master; count clipping BEFORE clamping; then hard/soft clip; then round as in e1601.
