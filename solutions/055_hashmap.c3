// =====================================================================
//  055 · HashMap{K, V} — хеш-таблица
// =====================================================================
//
//  Словарь «ключ -> значение» живёт в `std::collections::map`:
//
//      import std::collections::map;
//
//      HashMap{String, int} stock;
//      stock.init(mem);
//      defer stock.free();
//
//  Операции:
//      stock.set("apple", 5);          вставить или перезаписать
//      stock["apple"] = 5;             то же самое через оператор []=
//      stock.get("apple")              -> int?   (Optional!)
//      stock["apple"]                  -> int?   то же самое
//      stock.has_key("apple")          -> bool
//      stock.remove("apple");          удалить (если ключа нет — не страшно)
//      stock.len()                     количество пар
//      stock.keys(allocator)           -> String[] — НОВЫЙ срез ключей
//      stock.values(allocator)         -> int[]
//      stock.tkeys(), stock.tvalues()  то же во временном аллокаторе
//
//  Почему `get` возвращает Optional? Ключа может не быть — и это не
//  «ноль», а именно отсутствие (`NOT_FOUND`). C3 заставляет решить, что
//  делать в этом случае:
//      int n = stock.get("kiwi") ?? 0;     // нет ключа -> 0
//      int n = stock.get("apple")!!;       // «точно есть», иначе паника
//      if (try n = stock.get("apple")) ... // только если есть
//
//  Типичный приём «увеличить счётчик» поэтому выглядит так:
//      stock["apple"] = (stock["apple"] ?? 0) + 3;
//
//  ВЛАДЕНИЕ КЛЮЧАМИ: ключи-строки HashMap КОПИРУЕТ в свой аллокатор
//  (для типов, у которых есть `copy`). Поэтому в таблицу можно класть
//  временные строки — таблица не будет на них ссылаться. `free()`
//  освобождает и записи, и копии ключей.
//
//  ПОРЯДОК: порядок обхода хеш-таблицы не определён — он зависит от
//  хешей и ёмкости. Если вывод должен быть стабильным, возьмите ключи,
//  отсортируйте и печатайте по ним. Сортировка подробно будет в 067,
//  пока достаточно знать, что `quicksort(срез)` из `std::sort`
//  сортирует строки по алфавиту.
//
//  Как и List, неинициализированный HashMap при первой вставке сам
//  возьмёт временный аллокатор.
//
//  ЗАДАЧА: исправьте работу с Optional, передайте аллокатор в `keys`
//  и устраните утечку.
//  Ожидаемый вывод:
//      apple: 5, kiwi: 0
//      has pear: true
//      apple = 8
//      banana = 2
//      pear = 1
//
import std::io;
import std::collections::map;
import std::sort;

fn void main()
{
    @assert_leak()
    {
        HashMap{String, int} stock;
        stock.init(mem);
        defer stock.free();

        stock.set("apple", 5);
        stock["pear"] = 1;
        stock["plum"] = 4;
        @pool()
        {
            // временная строка в роли ключа — таблица сделает себе копию
            stock[string::tformat("ban%s", "ana")] = 2;
        };

        int apples = stock.get("apple") ?? 0;
        int kiwis = stock.get("kiwi") ?? 0;
        io::printfn("apple: %d, kiwi: %d", apples, kiwis);
        io::printfn("has pear: %s", stock.has_key("pear"));

        stock["apple"] = (stock["apple"] ?? 0) + 3;
        stock.remove("plum");
        assert(stock.len() == 3);

        @pool()
        {
            String[] names = stock.keys(tmem);
            quicksort(names);
            foreach (name : names) io::printfn("%s = %d", name, stock[name]!!);
        };
    };
}
