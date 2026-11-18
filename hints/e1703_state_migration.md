`migrate_v1_to_v2`: `*out = { .header = { STATE_MAGIC, 2, StateV2::size }, .unit_count = old.unit_count };`
then for each unit copy x, y, ammo; health = 100, team = i % 2.
`on_load_v2`: if the magic doesn't match - write a clean StateV2 with a version-2 header into memory.
If it's version 1 - `StateV2 tmp; migrate_v1_to_v2((StateV1*)&m.bytes, &tmp); tmp.migrations++;`
and only then copy tmp over the memory (`*(StateV2*)&m.bytes = tmp;`). Version 2 - do nothing.
