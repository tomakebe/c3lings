`advance`: если frame_time > max_frame — прибавьте разницу к clipped и обрежьте. `accumulator += frame_time`;
`while (accumulator >= dt) { accumulator -= dt; steps++; }`; `ticks += steps`.
`pressed`: бит есть в held и нет в prev; `released` — наоборот.
`record`: пропустить, если маска совпадает с `last` (или это нулевая маска в самом начале); иначе добавить
`{ tick, bits }` и запомнить last. `play`: `while (cursor < count && events[cursor].tick <= tick) current = events[cursor++].bits;`
