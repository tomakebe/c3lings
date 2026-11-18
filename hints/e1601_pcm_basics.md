Order in `f32_to_s16`: first clamp to [-1, 1], then multiply by 32767, then round.
Round-to-nearest for positive values is `+ 0.5f` and dropping the fraction with a `(short)` cast;
for negative values it's `- 0.5f` (casting to an integer truncates the fraction "toward zero").
In `peak_s16` compute the absolute value in `int`: `-(int)s`, not `-s` - a short has no room for +32768.
`interleave`: `out[2*i] = left[i]`, `out[2*i+1] = right[i]`.
