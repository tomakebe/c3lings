`str`: `uint i = (uint)sym; return (String)self.bytes.array_view()[self.starts[i]:self.lens[i]];`
`find_slot`: `i = (sz)hash & mask`; пока `table[i] != NO_SYMBOL` — сравнить `self.hashes[(uint)sym] == hash`
и `self.str(sym) == s`, иначе `i = (i + 1) & mask`. Пустая ячейка — тоже ответ.
`intern`: найден символ — вернуть. Иначе рост (и ПОВТОРНЫЙ find_slot — индексы поменялись!),
`Symbol sym = (Symbol)(uint)(self.count + 1);`, запишите start (= текущая длина bytes), len, hash,
затем `self.bytes.push_all((char[])s)`, `table[slot] = sym`, `count++`.
