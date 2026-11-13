FLOAT: `$if $Ty::size == 4: w.put_uint(bitcast(value, uint), 4); $else ... ulong, 8 $endif`;
чтение: `*ptr = bitcast((uint)r.get_uint(4)!, float);`.
ENUM: `w.put((char)value.ordinal)`; чтение — проверить `ord >= $Ty::len` → `BAD_ENUM~`, затем `$Ty::from_ordinal(ord)`.
ARRAY: `foreach (x : value) write_value(w, x);` / `foreach (&x : *ptr) read_value(r, x)!;`.
SLICE: `w.put_uint((ulong)value.len, 4)` + элементы; при чтении `*ptr = mem::talloc_array($Typefrom($Ty::inner), (sz)len);`.
STRUCT: `$foreach $m : $Ty::members: $if !$m.has_tag("transient"): write_value(w, value.$m); $endif $endforeach`
(для чтения — `read_value(r, &ptr.$m)!`).
