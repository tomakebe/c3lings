`split_rock`: если size <= 1 — выход. Скопируйте Transform и Velocity астероида (до того, как он будет удалён
в flush, они ещё на месте) и вызовите `spawn_rock` дважды с повёрнутыми скоростями из doc-комментария.
`on_collision`: сначала проверка `is_doomed`; затем определите, кто из двух — астероид (по `tags.get(...).kind`),
а кто «другой». Пуля: destroy_later обоих, очки, `rocks_destroyed++`, `split_rock`. Корабль: destroy_later
корабля, `has_ship = false`, `lives--`, `respawn_timer = RESPAWN_TICKS`.
В конце `update`: `if (self.rock_count() == 0) self.spawn_wave();`
