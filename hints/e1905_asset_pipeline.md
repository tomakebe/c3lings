`compute_key`: `h = fnv_u32(2166136261, g_builder_version[a.type])`, then `h = fnv(h, a.source)`,
then `fnv_u32(h, deps_hash)`.
`build(i)`: if `visited[i]` - return; mark it; recursively `build` all dependencies; `dh = self.deps_hash(a)`;
`key = compute_key(a, dh)`; if there's a cache entry and the key matches - return. Otherwise `a.output_hash = cook(a, dh)`,
store the key, `has_cache = true`, `cooked++` and print `io::printf(" %s", a.name)`.
