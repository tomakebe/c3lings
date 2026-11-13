// =====================================================================
//  113 · Интернирование строк
// =====================================================================
//
//  Компилятор видит идентификатор `position` тысячи раз. Движок сравнивает
//  имена анимаций, тегов, свойств материалов каждый кадр. Сравнение строк
//  — O(длины) и промах кеша на каждый байт-буфер; хранение копий —
//  лишняя память; строковые ключи в хеш-таблицах — хеширование снова и
//  снова.
//
//  ИНТЕРНИРОВАНИЕ: каждая уникальная строка хранится ровно один раз и
//  получает маленький целый номер — символ (Symbol). Дальше программа
//  оперирует только номерами:
//  * сравнение строк == сравнение uint, O(1);
//  * символ — идеальный ключ для массивов и хеш-таблиц;
//  * 4 байта вместо 16-байтного среза + копии текста.
//  Так делают: Lisp/Ruby/Erlang (symbols, atoms), Java String.intern,
//  компиляторы (у C3, Clang, rustc — таблица идентификаторов), Unreal
//  (FName), id Tech и Godot (StringName), Python для идентификаторов.
//
//  УСТРОЙСТВО
//  ----------
//      bytes:  "positionvelocityhealth..."   — все строки подряд (арена)
//      starts: [0, 8, 16, ...]               — начало строки символа
//      lens:   [8, 8, 6, ...]
//      hashes: [...]                          — кеш хешей (для роста таблицы)
//      table:  [0, 3, 0, 1, 0, 0, 2, ...]    — открытая адресация, в ячейке
//                                               лежит Symbol (0 = пусто)
//  Таблица хранит НЕ строки, а номера: ключ сравнивается через
//  `str(sym) == s`. Это компактно (4 байта на ячейку) и при росте таблицы
//  ничего, кроме номеров, двигать не надо.
//
//  ГЛАВНАЯ ЛОВУШКА: УКАЗАТЕЛИ В РАСТУЩИЙ БУФЕР
//  -------------------------------------------
//  Соблазнительно хранить для символа `String` — срез прямо в `bytes`.
//  Но `bytes` — растущий List: при очередном push он делает realloc,
//  и все ранее выданные срезы указывают в освобождённую память.
//  Поэтому храним СМЕЩЕНИЯ (starts/lens), а срез строим по запросу:
//  `str(sym)` валиден до следующего `intern`. Альтернативы из реальных
//  систем: арена из блоков, которые никогда не перемещаются (тогда
//  срезы стабильны навсегда), или копия строки на каждую запись.
//
//  Ещё нюансы:
//  * Символ 0 зарезервирован как «пусто» — удобно и для таблицы, и
//    как значение по умолчанию (`Symbol s;` == «нет символа»).
//  * typedef Symbol = uint — отдельный тип: нельзя случайно передать
//    счётчик вместо символа, и наоборот (приведения явные).
//  * Глобальный интернер + потоки = нужна синхронизация; часто делают
//    интернер на поток/на модуль компиляции и сливают в конце.
//  * Интернированные строки обычно не удаляют никогда (или чистят всё
//    разом вместе с ареной) — это сознательный компромисс.
//
//  ЗАДАЧА: реализуйте Interner.str, Interner.find_slot и Interner.intern.
//  Рост таблицы (grow_table) уже написан — используйте его, когда
//  загрузка превысит 1/2.
//
import std::io;
import std::collections::list;

typedef Symbol = uint;
const Symbol NO_SYMBOL = (Symbol)0;

struct Interner
{
    List{char} bytes;
    List{uint} starts;
    List{uint} lens;
    List{uint} hashes;
    Symbol[] table;      // длина — степень двойки
    sz count;            // число символов (без нулевого)
}

fn void Interner.init(&self)
{
    *self = {};
    self.bytes.init(mem);
    self.starts.init(mem);
    self.lens.init(mem);
    self.hashes.init(mem);
    // символ 0 — пустая запись
    self.starts.push(0);
    self.lens.push(0);
    self.hashes.push(0);
    self.table = mem::new_array(Symbol, 16);
}

fn void Interner.free(&self)
{
    self.bytes.free();
    self.starts.free();
    self.lens.free();
    self.hashes.free();
    free(self.table);
}

// Текст символа. Срез валиден до следующего вызова intern!
fn String Interner.str(&self, Symbol sym)
{
    // TODO: (String)self.bytes.array_view()[start:len]
    uint i = (uint)sym;
    return (String)self.bytes.array_view()[self.starts[i]:self.lens[i]];
}

// Индекс ячейки table: либо ячейка с символом, равным s, либо первая пустая.
fn sz Interner.find_slot(&self, String s, uint hash)
{
    // TODO: линейный пробинг; сравнивайте сначала хеш (self.hashes), потом текст.
    sz mask = self.table.len - 1;
    sz i = (sz)hash & mask;
    while (true)
    {
        Symbol sym = self.table[i];
        if (sym == NO_SYMBOL) return i;
        if (self.hashes[(uint)sym] == hash && self.str(sym) == s) return i;
        i = (i + 1) & mask;
    }
}

fn void Interner.grow_table(&self)
{
    Symbol[] old = self.table;
    self.table = mem::new_array(Symbol, old.len * 2);
    sz mask = self.table.len - 1;
    foreach (sym : old)
    {
        if (sym == NO_SYMBOL) continue;
        sz i = (sz)self.hashes[(uint)sym] & mask;
        while (self.table[i] != NO_SYMBOL) i = (i + 1) & mask;
        self.table[i] = sym;
    }
    free(old);
}

// Найти без вставки.
fn Symbol Interner.lookup(&self, String s)
{
    return self.table[self.find_slot(s, s.hash())];
}

fn Symbol Interner.intern(&self, String s)
{
    // TODO:
    //  1. h = s.hash(); slot = find_slot; если там символ — вернуть его;
    //  2. если (count + 1) * 2 > table.len — grow_table() и пересчитать slot;
    //  3. новый символ = count + 1: дописать байты (push_all), start/len/hash;
    //  4. записать символ в table[slot], count++.
    uint h = s.hash();
    sz slot = self.find_slot(s, h);
    if (self.table[slot] != NO_SYMBOL) return self.table[slot];
    if ((self.count + 1) * 2 > self.table.len)
    {
        self.grow_table();
        slot = self.find_slot(s, h);
    }
    Symbol sym = (Symbol)(uint)(self.count + 1);
    self.starts.push((uint)self.bytes.len());
    self.lens.push((uint)s.len);
    self.hashes.push(h);
    self.bytes.push_all((char[])s);
    self.table[slot] = sym;
    self.count++;
    return sym;
}

// ---------------------------------------------------------------- проверка

fn void main()
{
    Interner in;
    in.init();
    defer in.free();

    Symbol pos = in.intern("position");
    Symbol vel = in.intern("velocity");
    assert(pos != NO_SYMBOL && vel != NO_SYMBOL && pos != vel);

    // Та же строка из ДРУГОГО буфера даёт тот же символ.
    char[8] buf = "position";
    assert(in.intern((String)buf[..]) == pos, "same text must give the same symbol");
    assert(in.str(pos) == "position" && in.str(vel) == "velocity");
    assert(in.lookup("health") == NO_SYMBOL, "lookup must not insert");
    assert(in.count == 2);
    assert(in.intern("") != NO_SYMBOL && in.str(in.intern("")) == "", "empty string is a valid symbol");

    // Токенизация «исходника»: все имена превращаются в символы.
    String src = "let x = pos + vel ; let y = x * pos ; let pos = y - x ; print pos x y vel";
    Symbol[64] toks;
    sz n = 0;
    Splitter sp = src.tokenize(" ");
    while (try w = sp.next()) toks[n++] = in.intern(w);
    Symbol let_sym = in.lookup("let");
    sz lets = 0;
    foreach (t : toks[:n]) if (t == let_sym) lets++;   // сравнение — просто uint
    assert(lets == 3);
    io::printfn("tokens=%d unique symbols=%d lets=%d", n, in.count, lets);

    // Рост: тысячи символов, старые остаются корректными.
    for (int i = 0; i < 3000; i++)
    {
        @pool()
        {
            Symbol s = in.intern(string::tformat("name_%d", i % 1000));
            assert(in.str(s) == string::tformat("name_%d", i % 1000));
        };
    }
    assert(in.str(pos) == "position" && in.lookup("velocity") == vel, "old symbols broken after growth");
    Symbol n500 = in.lookup("name_500");
    assert(n500 != NO_SYMBOL && in.str(n500) == "name_500");
    io::printfn("after growth: symbols=%d table=%d bytes=%d", in.count, in.table.len, in.bytes.len());
    io::printfn("symbol of 'position' = %d, 'name_500' = %d", (uint)pos, (uint)n500);
}
