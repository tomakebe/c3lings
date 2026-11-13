`to_view`: возьмите `cy = icos(o.yaw)`, `sy = isin(o.yaw)`, `cp`, `sp` для pitch; каждое
выражение вида `(a * cos + b * sin) >> 12` — сдвиг после суммы. Порядок: yaw, pitch,
потом `* o.scale / 256` и `+ o.pos`.

`project`: `(long)W * SUB / 2 + (long)v.x * FOCAL * SUB / v.z` (для y — минус), третья
компонента `INV_Z_ONE / v.z`.

`draw_mesh`: `if (edge(a, b, c) <= 0) { f.tris_culled++; continue; }`. Для света есть готовые
`face_normal(va, vb, vc)` и `scale_channel(base.r, brightness)`.

`write_ppm`: `DString s; defer s.free(); s.appendf(...); s.append_char(c.r); ...`,
в конце `file::save(path, s.str_view())!;`.
