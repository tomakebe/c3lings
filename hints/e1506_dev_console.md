`tokenize`: индекс `i` по строке. Пробел/таб — пропустить; `;` — `i++` и выйти из цикла;
`"` — токен от символа после кавычки до следующей `"` (или конца), закрывающую кавычку
пропустить; иначе — до пробела/таба/`;`/`"`. Токен — срез `line[start:end - start]`,
кладите его, только если `n < out.len`. В конце `*consumed = i`.

`set_cvar`: сначала флаги (`cv.flags & CVAR_READONLY`, `cv.flags & CVAR_CHEAT && !self.cheats.b`),
потом `switch (cv.kind)` с `text.to_int()` / `text.to_float()` / `parse_bool(text)` и
`if (catch v) { печать; return false; }`, затем зажим в `[min, max]`.

`execute_tokens`: `find_cmd` → `cmd.handler(self, toks[1..])`; `find_cvar` → печать или
`set_cvar(cv, toks[1])`; иначе "unknown command: ...".

`complete`: соберите подходящие имена (`starts_with`) из команд и cvar'ов, затем
`sort::quicksort(out[:n], fn int(String a, String b) => a.compare_to(b));`.
