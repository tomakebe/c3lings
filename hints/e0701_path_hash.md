FNV-1a: `ulong h = FNV_OFFSET; foreach (c : data) h = (h ^ c) * FNV_PRIME;` — переполнение здесь законно.
В макросе то же через compile-time переменную: `var $h = FNV_OFFSET; $for var $i = 0; $i < $path.len; $i++: $h = ($h ^ $path[$i]) * FNV_PRIME; $endfor return $h;`.
normalize_path: внешний `while (i < path.len)`, внутри найдите конец сегмента `j`, `String seg = path[i:j - i]; i = j + 1;`.
На "..": `while (n > 0 && out[n - 1] != '/') n--; if (n > 0) n--;`. Перед записью сегмента проверьте `n + seg.len + 1 > out.len`.
register: `if (try existing = self.names.get(id)) { ... }`, строки сравниваются через `==`.
