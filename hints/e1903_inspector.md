В макросе оберните тело цикла в `$if !$m.has_tag("hidden"): ... $endif`, а после `$switch` добавьте
`$if $m.has_tag("min"): out[n].ranged = true; out[n].min = $m.get_tag("min"); out[n].max = $m.get_tag("max"); $endif`.
`set`: ограничьте value, если `p.ranged`; адрес — `void* at = (char*)self.object + p.offset;`
затем `switch (p.kind)`: `*(int*)at = (int)value`, `*(float*)at = (float)value`, `*(bool*)at = value != 0`.
`get` — то же чтение в обратную сторону (bool -> 1 или 0).
