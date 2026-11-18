Resampling: `usz i = (usz)(pos >> 16)`, `int frac = (int)(pos & 0xFFFF)`; neighbours a = input[i], b = input[i+1]
(past the end - `input[^1]`); the result is `a + (((b - a) * frac) >> 16)`; after writing, `pos += step`.
Filter: keep y in a local variable and store it back to `self.y` at the end.
ADSR: `switch (self.stage)`: ATTACK adds `1/attack` and at >= 1 moves to DECAY;
DECAY subtracts `(1 - sustain)/decay` and at <= sustain moves to SUSTAIN; RELEASE subtracts `release_step`
and at <= 0 zeroes the level and moves to IDLE. In C3 `case` has no fallthrough - no `break` needed.
