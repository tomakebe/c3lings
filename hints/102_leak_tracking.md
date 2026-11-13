Фаза 1: List.free освобождает только буфер списка. Строки-имена были скопированы через `name.copy(self.alloc)` — освободите каждую в Inventory.free: `item.name.free(self.alloc)`.
Фаза 2 и 3: массив `sorted` нужен только внутри make_report — поставьте `defer alloc::free(a, sorted);` сразу после выделения (сработает и при возврате ошибки).
Фаза 2: строка-результат make_report принадлежит вызывающему — в main добавьте `defer r.free(a);`.
