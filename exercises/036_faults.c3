// =====================================================================
//  036 · Встроенные ошибки, `switch` по ошибкам, описание ошибок
// =====================================================================
//
//  Не обязательно объявлять свои ошибки на каждый случай. Стандартная
//  библиотека уже содержит общие ошибки, помеченные `@builtin` — их
//  можно писать без префикса модуля (см. lib/std/core/builtin.c3):
//
//      NOT_FOUND          элемента нет в коллекции
//      NO_MORE_ELEMENT    итератор кончился / выход за границы
//      TYPE_MISMATCH      преобразование типа не удалось
//      CAPACITY_EXCEEDED  ограниченный контейнер переполнен
//      NOT_IMPLEMENTED    возможность недоступна
//      TIMEOUT            вышло время / превышен лимит попыток
//
//  Остальные ошибки живут в своих модулях и пишутся с префиксом:
//  `io::FILE_NOT_FOUND`, `io::EOF`, `string::MALFORMED_INTEGER`,
//  `string::EMPTY_STRING`, `mem::OUT_OF_MEMORY`...
//
//  `fault` — обычный тип-значение размером с указатель:
//  * его можно хранить в переменных, массивах, полях структур;
//  * сравнивать через `==`;
//  * нулевое значение `fault` (по умолчанию) означает «ошибки нет»
//    и в условиях ведёт себя как false: `if (f) ...`;
//  * у него есть поле `.description` — строка вида "модуль::ИМЯ",
//    например "builtin::NOT_FOUND" или "io::EOF". Для «пустого» fault'а
//    это пустая строка. Печать `%s` fault'а даёт то же самое.
//
//  `switch` по fault'у работает так же, как по enum'у: метки — значения
//  ошибок, `break` неявный, пустой case «проваливается» в следующий:
//
//      switch (err)
//      {
//          case io::FILE_NOT_FOUND:
//          case io::NO_PERMISSION:  show("cannot open");   // обе ошибки сюда
//          case io::EOF:            show("file truncated");
//          default:                 show("something else");
//      }
//
//  Совет из практики: `.description` — для логов и отладки, а
//  пользователю лучше показывать собственный понятный текст.
//
//  ЗАДАЧА: почините три места, помеченные `// <-`.
//
import std::io;

struct Inventory
{
    String[3] names;
    int[3] counts;
    usz len;
}

fn void? Inventory.add(&self, String name, String count_text)
{
    if (self.len == self.names.len) return CAPACITY_EXCEEDED~;
    int count = count_text.to_int()!;
    self.names[self.len] = name;
    self.counts[self.len] = count;
    self.len++;
}

fn int? Inventory.count_of(&self, String name)
{
    for (usz i = 0; i < self.len; i++)
    {
        if (self.names[i] == name) return self.counts[i];
    }
    return ???~; // <- встроенная ошибка «элемента нет»
}

fn String explain(fault f)
{
    switch (f)
    {
        case CAPACITY_EXCEEDED: return "inventory is full";
        case NOT_FOUND: return "no such item";
        case EMPTY_STRING: // <- обе ошибки разбора числа
        case string::MALFORMED_INTEGER: return "bad number";
        default: return "unexpected error";
    }
}

fn void main()
{
    Inventory inv;
    fault[6] results;
    results[0] = @catch(inv.add("sword", "1"));
    results[1] = @catch(inv.add("arrow", "x20"));
    results[2] = @catch(inv.add("arrow", "20"));
    results[3] = @catch(inv.add("bread", ""));
    results[4] = @catch(inv.add("bread", "3"));
    results[5] = @catch(inv.add("shield", "1"));

    foreach (i, f : results)
    {
        if (f) // <- «ошибки нет»
        {
            io::printfn("add #%d: ok", i);
            continue;
        }
        io::printfn("add #%d: %s (%s)", i, explain(f), f.description);
    }

    foreach (name : (String[]){ "arrow", "potion" })
    {
        int? n = inv.count_of(name);
        if (catch err = n)
        {
            io::printfn("%s: %s", name, explain(err));
            continue;
        }
        io::printfn("%s: %d", name, n);
    }
    assert(@catch(inv.count_of("potion")) == NOT_FOUND);
}
