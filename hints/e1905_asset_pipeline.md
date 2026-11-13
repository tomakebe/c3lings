`compute_key`: `h = fnv_u32(2166136261, g_builder_version[a.type])`, затем `h = fnv(h, a.source)`,
затем `fnv_u32(h, deps_hash)`.
`build(i)`: если `visited[i]` — выйти; пометить; рекурсивно `build` все зависимости; `dh = self.deps_hash(a)`;
`key = compute_key(a, dh)`; если кэш есть и ключ совпал — выйти. Иначе `a.output_hash = cook(a, dh)`,
сохранить ключ, `has_cache = true`, `cooked++` и напечатать `io::printf(" %s", a.name)`.
