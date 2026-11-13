* Начните с `crc32`: формула есть в главе 13.6; `assert` на `0xCBF43926` в начале `main` скажет, верна ли она.
* `save_game`: после magic/version/flags запомните `usz size_at = w.len;` и запишите два `w.u32(0)`. Начало payload'а — `usz start = w.len;`. В конце `char[] payload = w.data[start:w.len - start];` и два `patch_u32` (size по `size_at`, crc по `size_at + 4`).
* Сущности пишите из копии `Entity[MAX_ENTITIES] ents = world.sorted();` — только первые `world.count`. anim_time не пишется.
* `load_game`: разберите заголовок отдельным `ByteReader` по `file[:HEADER_SIZE]`, проверки — строго в порядке из шапки. Payload — `file[HEADER_SIZE..]`.
* Версия 1: `SaveV1 old = read_payload_v1(&r)!; w = migrate_v1_to_v2(&old);`. В миграции считайте координаты в int и только потом приводите к float; hp — `(ushort)e.hp * 10`.
