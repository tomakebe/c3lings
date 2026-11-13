// =====================================================================
//  108 · Generic хеш-таблица с открытой адресацией с нуля
// =====================================================================
//
//  Хеш-таблица — самая используемая структура данных после массива.
//  В стандартной библиотеке C3 есть HashMap (цепочки в бакетах), но
//  в движках, компиляторах и БД почти всегда пишут свою: под конкретные
//  ключи, аллокатор и профиль нагрузки. Сегодня пишем такую таблицу.
//
//  ДВА СЕМЕЙСТВА
//  -------------
//  * Separate chaining: массив бакетов, в каждом — связный список.
//    Простое удаление, но каждый узел — отдельная аллокация и промах
//    кеша при обходе цепочки (std::unordered_map, Java HashMap).
//  * Open addressing: все записи лежат прямо в одном массиве слотов.
//    При коллизии ищем следующий свободный слот по правилу «пробинга».
//    Один плотный массив => отличная локальность. Так устроены
//    Swiss Table (absl/Rust hashbrown), F14 (Facebook), таблицы
//    в LuaJIT, V8, большинстве игровых движков.
//
//  ПРОБИНГ
//  -------
//  * Линейный: i, i+1, i+2, ... Лучший для кеша, но склонен к
//    «кластеризации» — длинным сплошным участкам занятых слотов.
//  * Квадратичный / двойное хеширование: меньше кластеров, хуже кеш.
//  * Robin Hood: линейный, но «бедные» (далеко ушедшие от своего
//    идеального слота) элементы вытесняют «богатых» — выравнивает
//    длины поиска.
//  Мы берём линейный пробинг + ёмкость — степень двойки, чтобы вместо
//  дорогого `%` использовать маску: `idx = hash & (cap - 1)`.
//  Внимание: маска берёт МЛАДШИЕ биты хеша; плохой хеш (например,
//  identity для указателей, выровненных по 16) даст массу коллизий.
//  Поэтому хеш перемешивают (в std C3 `x.hash()` уже хорошо мешает).
//
//  УДАЛЕНИЕ — главная тонкость
//  ---------------------------
//  Нельзя просто пометить слот пустым: поиск ключа, который при вставке
//  «перепрыгнул» через этот слот, остановится на дыре и вернёт «нет».
//  Варианты:
//  1. Tombstone (надгробие): слот помечается «удалён» — поиск идёт
//     дальше, вставка может его переиспользовать. Просто, но надгробия
//     копятся и деградируют таблицу => нужна периодическая пересборка.
//  2. Backward-shift deletion (для линейного пробинга): после удаления
//     идём вперёд по кластеру и сдвигаем назад каждый элемент, который
//     «имеет право» стоять раньше. Надгробий нет вовсе. Это делаем мы.
//
//  Условие сдвига. Пусть дыра в слоте `hole`, рассматриваем элемент в
//  слоте `j`, его идеальный слот `home = hash & mask`. Элемент можно
//  перенести в дыру, если `home` НЕ лежит циклически в полуинтервале
//  (hole, j]. Проще всего считать расстояния по модулю ёмкости:
//      dist(a, b) = (b - a) & mask      // сколько шагов от a до b
//      сдвигать, если dist(home, j) >= dist(hole, j)
//  Кластер заканчивается на первом пустом слоте.
//
//  РОСТ: держим загрузку <= 3/4. Линейный пробинг резко деградирует
//  после ~0.8. При росте нельзя скопировать массив байт в байт — индексы
//  зависят от ёмкости, все элементы надо заново вставить (rehash).
//  Храним полный хеш в записи: при rehash не пересчитываем его, а при
//  поиске сначала сравниваем дешёвый uint и только потом ключ (для
//  строк это экономит memcmp).
//
//  ЗАДАЧА: реализуйте методы OaMap, помеченные TODO:
//    find_slot — индекс слота с ключом, либо первого пустого слота;
//    set       — вставка/обновление (с ростом при загрузке > 3/4);
//    get       — Value? (NOT_FOUND~, если ключа нет);
//    remove    — с backward-shift deletion; возвращает true, если удалил.
//  grow/init/free уже написаны.
//
import std::io;

excuse NOT_FOUND;

struct Slot <Key, Value>
{
    Key key;
    Value value;
    uint hash;
    bool used;
}

struct OaMap <Key, Value>
{
    Slot{Key, Value}[] slots;   // длина — степень двойки
    sz len;
}

fn void OaMap.init(&self, sz cap = 8)
{
    assert(cap > 0 && (cap & (cap - 1)) == 0, "capacity must be a power of two");
    self.slots = mem::new_array(Slot{Key, Value}, cap);
    self.len = 0;
}

fn void OaMap.free(&self)
{
    free(self.slots);
    *self = {};
}

fn sz OaMap.mask(&self) @inline => self.slots.len - 1;

// Найти слот: либо там лежит key, либо это первый пустой слот на пути
// пробинга (куда key можно вставить). Таблица никогда не бывает полной,
// поэтому цикл всегда завершится.
fn sz OaMap.find_slot(&self, Key key, uint hash)
{
    // TODO: начать с hash & mask, идти вперёд (по маске), пока слот занят
    //       и (хеш другой ИЛИ ключ другой).
    return 0;
}

fn void OaMap.grow(&self)
{
    Slot{Key, Value}[] old = self.slots;
    self.slots = mem::new_array(Slot{Key, Value}, old.len * 2);
    foreach (&s : old)
    {
        if (!s.used) continue;
        sz i = self.find_slot(s.key, s.hash);
        self.slots[i] = *s;
    }
    free(old);
}

fn void OaMap.set(&self, Key key, Value value)
{
    // TODO: если (len + 1) * 4 > cap * 3 — grow(); затем find_slot;
    //       если слот пустой — это новая запись (len++).
}

fn Value? OaMap.get(&self, Key key)
{
    // TODO
    return NOT_FOUND~;
}

fn bool OaMap.has(&self, Key key) => @ok(self.get(key));

fn bool OaMap.remove(&self, Key key)
{
    // TODO: найти слот; если пуст — false. Иначе сделать дыру и
    //       выполнить backward shift (см. шапку), len--.
    return false;
}

// Проверка инварианта: в таблице нет «потерянных» элементов — каждый
// занятый слот достижим поиском от своего идеального слота.
fn bool OaMap.check_invariant(&self)
{
    sz count = 0;
    foreach (i, &s : self.slots)
    {
        if (!s.used) continue;
        count++;
        if (self.find_slot(s.key, s.hash) != i) return false;
    }
    return count == self.len;
}

// ---------------------------------------------------------------- проверка

alias IntMap = OaMap{int, int};
alias WordMap = OaMap{String, int};

fn void main()
{
    // --- базовые операции
    IntMap m;
    m.init();
    defer m.free();
    m.set(1, 10);
    m.set(2, 20);
    m.set(1, 11);
    assert(m.len == 2, "set must update existing keys, not duplicate them");
    assert(m.get(1)!! == 11 && m.get(2)!! == 20);
    assert(!@ok(m.get(3)), "missing key must be NOT_FOUND");
    assert(m.remove(1) && !m.remove(1) && m.len == 1);
    assert(!m.has(1) && m.has(2));

    // --- нагрузка: вставки, рост, удаления
    for (int i = 0; i < 10000; i++) m.set(i * 7, i);
    assert(m.len == 10001, "len=%d", m.len);   // 10000 новых + ключ 2
    assert(m.check_invariant(), "invariant broken after inserts");
    for (int i = 0; i < 10000; i += 2) assert(m.remove(i * 7), "remove %d failed", i * 7);
    assert(m.check_invariant(), "invariant broken after removes (backward shift?)");
    sz found = 0;
    long sum = 0;
    for (int i = 0; i < 10000; i++)
    {
        if (try v = m.get(i * 7))
        {
            assert(i % 2 == 1);
            found++;
            sum += v;
        }
    }
    assert(found == 5000);
    io::printfn("int map: len=%d cap=%d found=%d sum=%d", m.len, m.slots.len, found, sum);

    // --- строки: частоты слов
    WordMap words;
    words.init(4);
    defer words.free();
    String text = "the quick brown fox jumps over the lazy dog the fox barks and the dog runs";
    Splitter sp = text.tokenize(" ");
    while (try w = sp.next())
    {
        words.set(w, (words.get(w) ?? 0) + 1);
    }
    assert(words.check_invariant());
    String[*] queries = { "the", "fox", "dog", "cat", "runs" };
    foreach (q : queries) io::printfn("%-5s -> %d", q, words.get(q) ?? 0);
    assert(words.remove("the") && !words.has("the") && words.has("fox"));
    assert(words.check_invariant());
    io::printfn("unique words left: %d", words.len);
}
