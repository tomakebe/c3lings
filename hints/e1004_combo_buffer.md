`mirror` — обычный `switch` по символам '1','3','4','6','7','9'; остальное возвращается как есть.
`match_motion`, шаг 1: `for (uint i = 0; i < buf.len(); i++)`, `e = buf.back(i)`; прерывайтесь, как только
`now - e.frame > BUTTON_BUFFER` или `e.frame <= buf.consumed_frame` (так же устроен поиск PUNCH в `detect`).
Шаг 2: индекс `want = m.dirs.len - 1`, `last_frame = press_frame`; идите от записи нажатия к старым.
Сначала проверки провала (`e.frame + STEP_GAP < last_frame`, потраченная запись — кроме самой записи
нажатия), потом сравнение `facing_right ? e.dir : mirror(e.dir)` с `m.dirs[want]`.
Нашли первый шаг (`want == 0`) — проверьте `press_frame - e.frame <= m.window`.
