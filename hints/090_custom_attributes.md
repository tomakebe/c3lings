`attrmacro @Json(name) = @tag("json", name);` и `attrmacro @Skip = @tag("skip", true);`.
В `to_json` оберните вывод поля в `$if !$f.has_tag("skip"): ... $endif`.
Имя поля: `$if $f.has_tag("json"):` → `$f.get_tag("json")`, иначе `$f.name`.
