`find`: линейный поиск по `self.slots[0..count)`, сравнение `self.slots[i].name() == name`.
`get`: найдите слот или создайте (`self.create(name, major)`); если `s.major != major` — null,
иначе `&s.data`. `set`: найдите или создайте слот, обновите major/minor, скопируйте байты:
`s.data[:size] = ((char*)api)[:size];` и `implemented = true`.
`remove`: обнулите данные (`s.data[..] = 0;`) и `implemented = false`, но слот не удаляйте.
