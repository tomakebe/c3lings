Править нужно `exercises/123_api_design/gfx.c3`.
Упаковка: `(TextureId)(slot | (uint)gen << 16)`; распаковка — `(uint)id & 0xFFFF` и `(ushort)((uint)id >> 16)`.
`lookup`: слот `< SLOTS`, запись `alive`, `r.gen == generation_of(id)` — иначе `STALE_HANDLE~`.
Методы builder'а: `self.width = w; self.height = h; return self;` — self здесь копия, это нормально.
`build`: сначала валидация (размер, затем pow2 для mipmaps), потом `foreach (i, &r : records)` по
свободным слотам; `if (r.gen == 0) r.gen = 1;`, заполнить запись, `return make_id((uint)i, r.gen);`.
