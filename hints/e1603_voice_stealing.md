`play`: сначала ищите неактивный слот. Если его нет — пройдите по всем голосам и выберите жертву,
сравнивая по ключу (priority, затем volume, затем start_tick) — у кого меньше, тот жертва.
Если `victim.priority > priority` — `rejected++` и вернуть `{ INVALID_INDEX, 0 }`. Иначе `stolen++`.
В выбранном слоте: `gen++`, заполнить поля, `start_tick = self.tick`, вернуть `{ (ushort)slot, gen }`.
`is_playing`: хендл валиден, слот активен и `gen` совпадает. `stop`: только если `is_playing`, и тоже `gen++`.
