Выравнивание: `while ((usz)out.len() % ALIGN != 0) out.push(0);` (List.len() возвращает знаковый `sz`).
Сортировка: `sort::quicksort(entries, fn int(TocEntry a, TocEntry b) => a.id < b.id ? -1 : (a.id > b.id ? 1 : 0));`.
Бинарный поиск по полуинтервалу: `usz lo = 0, hi = self.count; while (lo < hi) { usz mid = lo + (hi - lo) / 2; ... }`, а `if/else` в C3 всегда с фигурными скобками.
Запись TOC номер mid начинается с `self.toc + mid * TOC_ENTRY_SIZE`.
В acquire: `char[]? data = pak.find(id); if (catch data) continue;` — после этого `data` распакован.
