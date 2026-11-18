FNV-1a: `ulong h = FNV_OFFSET; foreach (c : data) h = (h ^ c) * FNV_PRIME;` — overflow is perfectly legal here.
In the macro, the same thing with a compile-time variable: `var $h = FNV_OFFSET; $for var $i = 0; $i < $path.len; $i++: $h = ($h ^ $path[$i]) * FNV_PRIME; $endfor return $h;`.
normalize_path: an outer `while (i < path.len)`; inside, find the end of the segment `j`, `String seg = path[i:j - i]; i = j + 1;`.
On "..": `while (n > 0 && out[n - 1] != '/') n--; if (n > 0) n--;`. Before writing a segment, check `n + seg.len + 1 > out.len`.
register: `if (try existing = self.names.get(id)) { ... }`; strings are compared with `==`.
