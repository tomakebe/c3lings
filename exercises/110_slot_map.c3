// =====================================================================
//  110 · Generic slot map с поколениями (handles)
// =====================================================================
//
//  ПРОБЛЕМА ССЫЛОК
//  ---------------
//  В игре снаряд помнит цель, UI помнит выделенный юнит, скрипт помнит
//  сущность. Чем ссылаться?
//  * Указатель: если хранилище — растущий массив, при realloc все
//    указатели протухают; если объект удалён — висячий указатель,
//    use-after-free, а при повторном использовании памяти ещё хуже:
//    указатель «работает», но смотрит на ДРУГОЙ объект (проблема ABA).
//  * Индекс в массиве: переживает realloc, но не удаление — после
//    swap-remove (упр. 106) по индексу лежит уже кто-то другой.
//
//  РЕШЕНИЕ: handle = (индекс слота, поколение).
//  ------------------------------------------
//  Каждый слот хранит счётчик поколения. При удалении объекта поколение
//  слота увеличивается. Handle валиден, только если его поколение
//  совпадает с текущим поколением слота. Старый handle на
//  переиспользованный слот мгновенно распознаётся как «протухший» —
//  проверка за O(1), без подсчёта ссылок и без GC.
//  Так устроены: entity id в EnTT/flecs/bevy (index + generation),
//  ресурсы в bgfx/sokol (sg_buffer), Rust-крейты slotmap и
//  generational-arena, хендлы объектов ядра Windows.
//
//  ПЛОТНОЕ ХРАНЕНИЕ (dense slot map)
//  ---------------------------------
//  Простейший slot map хранит значения прямо в слотах — тогда в массиве
//  дыры, и обход «всех живых» прыгает по пустым слотам. Мы сделаем
//  вариант с тремя массивами (как DenseSlotMap / sparse set в ECS):
//
//      slots:   [ {gen, idx} ... ]   // индексируется handle.index
//      values:  [ v0 v1 v2 ... ]     // ПЛОТНО, без дыр — быстрый обход
//      owners:  [ s0 s1 s2 ... ]     // owners[d] = номер слота, чьё значение в values[d]
//
//  У занятого слота `idx` — позиция значения в `values`. У свободного
//  слота то же поле `idx` — номер следующего свободного слота (free list
//  прямо внутри массива, без отдельной памяти). FREE_END — конец списка.
//
//  Удаление по handle h:
//      d = slots[h.index].idx                // где лежит значение
//      last = values.len - 1
//      values[d] = values[last]; owners[d] = owners[last]   // swap-remove
//      slots[owners[d]].idx = d             // ПОЧИНИТЬ слот переехавшего!
//      values.len--, owners.len--
//      slot.gen++; slot.occupied = false; slot -> в голову free list
//  Забыть починить слот переехавшего элемента — главный баг таких
//  структур: его handle начинает указывать за конец массива.
//
//  Нюансы реальных реализаций: переполнение поколения (слот «на пенсию»,
//  когда gen дошёл до максимума), типизированные хендлы (`typedef
//  TextureHandle = Handle;` — нельзя передать хендл меша вместо
//  текстуры), упаковка index+gen в один ulong для хеширования.
//
//  ЗАДАЧА: реализуйте insert, get, remove и is_valid. Внутренние массивы
//  — List из stdlib. main() сверяет slot map с простой моделью на
//  тысячах случайных операций.
//
import std::io;
import std::collections::list;

excuse STALE_HANDLE;

struct Handle
{
    uint index;
    uint gen;
}

const uint FREE_END = uint::max;

struct SlotEntry
{
    uint gen;       // текущее поколение
    uint idx;       // занят: позиция в values; свободен: следующий свободный слот
    bool occupied;
}

struct SlotMap <Type>
{
    List{SlotEntry} slots;
    List{Type} values;
    List{uint} owners;
    uint free_head;
}

fn void SlotMap.init(&self)
{
    *self = { .free_head = FREE_END };
    self.slots.init(mem);
    self.values.init(mem);
    self.owners.init(mem);
}

fn void SlotMap.free(&self)
{
    self.slots.free();
    self.values.free();
    self.owners.free();
}

fn sz SlotMap.len(&self) => self.values.len();

// Плотный срез всех живых значений — для быстрого обхода.
fn Type[] SlotMap.as_slice(&self) => self.values.array_view();

fn Handle SlotMap.insert(&self, Type value)
{
    // TODO:
    //  * взять слот из free list (если free_head != FREE_END), иначе
    //    добавить новый слот с gen = 1;
    //  * дописать value в values и номер слота в owners;
    //  * slot.idx = позиция в values, occupied = true;
    //  * вернуть { номер слота, slot.gen }.
    return {};
}

fn bool SlotMap.is_valid(&self, Handle h)
{
    // TODO: индекс в пределах, слот занят и поколения совпадают.
    return true;
}

fn Type*? SlotMap.get(&self, Handle h)
{
    // TODO: STALE_HANDLE~ для невалидного handle, иначе указатель на значение.
    return STALE_HANDLE~;
}

fn void? SlotMap.remove(&self, Handle h)
{
    // TODO: алгоритм из шапки. Не забудьте починить слот переехавшего элемента.
}

// ---------------------------------------------------------------- проверка

struct Unit
{
    int id;
    int hp;
}

struct Model
{
    Handle h;
    int id;
    bool alive;
}

uint seed = 99;
fn uint rnd(uint n)
{
    seed = seed * 1103515245 + 12345;
    return ((seed >> 16) & 0x7FFF) % n;
}

fn void main()
{
    SlotMap{Unit} units;
    units.init();
    defer units.free();

    Handle a = units.insert({ 1, 100 });
    Handle b = units.insert({ 2, 80 });
    Handle c = units.insert({ 3, 60 });
    assert(units.len() == 3);
    assert(units.get(b)!!.hp == 80);
    units.get(b)!!.hp -= 30;                     // указатель на живое значение
    assert(units.get(b)!!.hp == 50);

    units.remove(a)!!;                           // a был в начале: c переезжает на его место
    assert(units.len() == 2);
    assert(!units.is_valid(a));
    assert(@catch(units.get(a)) == STALE_HANDLE);
    assert(@catch(units.remove(a)) == STALE_HANDLE, "double remove must fail");
    assert(units.get(c)!!.id == 3, "moved element lost (slot of moved value not fixed?)");

    Handle d = units.insert({ 4, 40 });          // переиспользует слот a
    assert(d.index == a.index && d.gen != a.gen, "slot must be reused with a new generation");
    assert(!units.is_valid(a), "ABA: old handle must stay invalid");
    assert(units.get(d)!!.id == 4);
    assert(!units.is_valid({ 100, 1 }), "out of range index");

    int hp = 0;
    foreach (u : units.as_slice()) hp += u.hp;
    io::printfn("units=%d total hp=%d", units.len(), hp);

    // --- стресс против простой модели
    List{Model} model;
    model.init(mem);
    defer model.free();
    int next_id = 1000;
    int stale_hits = 0;
    for (int step = 0; step < 5000; step++)
    {
        uint op = rnd(10);
        if (op < 5 || model.len() == 0)
        {
            Handle h = units.insert({ next_id, next_id % 97 });
            model.push({ h, next_id, true });
            next_id++;
        }
        else
        {
            Model* m = model.get_ref(rnd((uint)model.len()));
            if (m.alive)
            {
                units.remove(m.h)!!;
                m.alive = false;
            }
            else
            {
                assert(!units.is_valid(m.h));
                stale_hits++;
            }
        }
    }
    sz alive = 0;
    foreach (m : model)
    {
        if (m.alive)
        {
            alive++;
            assert(units.get(m.h)!!.id == m.id, "handle %d:%d points to the wrong value", m.h.index, m.h.gen);
        }
        else
        {
            assert(!units.is_valid(m.h));
        }
    }
    assert(alive + 3 == units.len());           // + b, c и d из начала
    io::printfn("stress: alive=%d slots=%d stale checks=%d", units.len(), units.slots.len(), stale_hits);
    io::printn("all handles verified");
}
