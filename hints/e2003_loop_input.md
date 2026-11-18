`advance`: if frame_time > max_frame - add the difference to clipped and clamp it. `accumulator += frame_time`;
`while (accumulator >= dt) { accumulator -= dt; steps++; }`; `ticks += steps`.
`pressed`: the bit is in held and not in prev; `released` - the other way round.
`record`: skip if the mask equals `last` (or it's a zero mask at the very start); otherwise append
`{ tick, bits }` and remember last. `play`: `while (cursor < count && events[cursor].tick <= tick) current = events[cursor++].bits;`
