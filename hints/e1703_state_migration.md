`migrate_v1_to_v2`: `*out = { .header = { STATE_MAGIC, 2, StateV2::size }, .unit_count = old.unit_count };`
затем для каждого юнита скопируйте x, y, ammo; health = 100, team = i % 2.
`on_load_v2`: если magic не совпадает — запишите в память чистое StateV2 с заголовком версии 2.
Если версия 1 — `StateV2 tmp; migrate_v1_to_v2((StateV1*)&m.bytes, &tmp); tmp.migrations++;`
и только потом скопируйте tmp поверх памяти (`*(StateV2*)&m.bytes = tmp;`). Версия 2 — ничего.
