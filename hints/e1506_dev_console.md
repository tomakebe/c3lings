`tokenize`: an index `i` over the line. Space/tab - skip; `;` - `i++` and break out of the loop;
`"` - the token runs from the character after the quote to the next `"` (or the end), skip the closing
quote; otherwise - up to a space/tab/`;`/`"`. A token is the slice `line[start:end - start]`,
store it only if `n < out.len`. At the end `*consumed = i`.

`set_cvar`: flags first (`cv.flags & CVAR_READONLY`, `cv.flags & CVAR_CHEAT && !self.cheats.b`),
then `switch (cv.kind)` with `text.to_int()` / `text.to_float()` / `parse_bool(text)` and
`if (catch v) { print; return false; }`, then clamp to `[min, max]`.

`execute_tokens`: `find_cmd` -> `cmd.handler(self, toks[1..])`; `find_cvar` -> print or
`set_cvar(cv, toks[1])`; otherwise "unknown command: ...".

`complete`: collect matching names (`starts_with`) from commands and cvars, then
`sort::quicksort(out[:n], fn int(String a, String b) => a.compare_to(b));`.
