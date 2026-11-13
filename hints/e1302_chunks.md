* `end_chunk`: поле size занимает 4 байта начиная с `size_at`, значит payload начинается с `size_at + 4`, а его длина — `self.len - (size_at + 4)`.
* `load_level`: сначала magic и version, затем `while (r.remaining() > 0)` — читать tag и size, проверить `size > r.remaining()`.
* Запомните `usz end = r.pos + size;` ДО разбора payload'а и в конце итерации сделайте `r.pos = end;` — это и пропуск незнакомых чанков, и защита от расширенных.
* В `switch (tag)` используйте константы `TAG_NAME`, `TAG_SIZE`, `TAG_GRAV`; в `default` увеличьте `skipped_chunks`.
* Заведите флаги `has_name`/`has_size`; без них нельзя отличить «чанка не было» от «там нули».
