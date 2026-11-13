* Скопируйте структуру `@save` и замените в ней `x` на `*ptr`, а каждую запись — на соответствующее чтение: `*ptr = r.u16()!;`, `*ptr = bitcast(r.u32()!, float);`, `*ptr = (int)r.u32()!;`.
* bool читайте через `switch (r.u8()!)` с ветками 0, 1 и `default: return CORRUPT~;`.
* Для вложенных полей передавайте адрес: `@load(r, version, &ptr.$eval($f.name))!;`. Для массива — `foreach (&e : *ptr) @load(r, version, e)!;`.
* Версию проверяет рантайм-условие, а наличие тега — compile-time: внутри `$if $f.has_tag("since"):` напишите обычный `if (version >= $f.get_tag("since")) ...`.
* Тип и вид типа: `$switch $Typeof(*ptr):` и `$if $Typeof(*ptr)::kind == ARRAY:`.
