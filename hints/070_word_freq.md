normalize: пройдите `foreach (c : raw)`, добавляйте в DString (`s.tinit()`) только `c.is_alpha()` или `'\''`,
переводя `c.to_lower()`; верните `s.str_view()` (он во временной памяти — это нормально).
count_words: два вложенных `while (try ... = splitter.next())` — по строкам (`tokenize("\n")`) и по словам
(`tokenize(" ")`); пустые слова пропускайте; `(*counts)[w] = ((*counts)[w] ?? 0) + 1;`.
by_frequency: если count различаются — `compare_to(b.count, a.count)`, иначе `a.word.compare_to(b.word)`.
