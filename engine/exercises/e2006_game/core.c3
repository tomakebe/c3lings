// ---------------------------------------------------------------------
//  mini::core — фундамент мини-движка: фиксированная точка, кадровая
//  арена, пул хендлов с поколениями, хеш и генератор случайных чисел.
//  (главы 02, 03, 01)
// ---------------------------------------------------------------------
module mini::core;

// Фиксированная точка 24.8: 1.0 == FX. Вся симуляция — в целых числах,
// поэтому она побитно детерминирована на любом процессоре (глава 01).
const int FX = 256;

// ---------------------------------------------------------------- арена
// Линейный (кадровый) аллокатор: выделение — сдвиг указателя,
// освобождение — reset() всего сразу в конце кадра.
struct Arena
{
    char* base;
    usz cap;
    usz used;
    usz peak;      // максимум used за всё время — для бюджета памяти
    int failed;    // сколько раз не хватило места
}

fn void Arena.init(&self, char[] backing)
{
    *self = { .base = backing.ptr, .cap = backing.len };
}

<*
 Выделить size байт с выравниванием align (степень двойки).
 Память НЕ обнуляется. Если места нет — failed++ и null.
*>
fn void* Arena.alloc(&self, usz size, usz align = 16)
{
    assert(align > 0 && (align & (align - 1)) == 0, "align должен быть степенью двойки");
    usz start = (self.used + align - 1) & ~(align - 1);
    if (start + size > self.cap)
    {
        self.failed++;
        return null;
    }
    self.used = start + size;
    if (self.used > self.peak) self.peak = self.used;
    return self.base + start;
}

fn void Arena.reset(&self)
{
    self.used = 0;
}

macro Arena.new_array(&self, $Type, usz n)
{
    $Type* p = self.alloc($Type::size * n, $Type::alignment);
    assert(p != null, "кадровая арена переполнена");
    return p[:n];
}

// ------------------------------------------------------ пул хендлов
const uint MAX_ENTITIES = 128;

struct Handle
{
    uint index;
    uint gen;
}

excuse POOL_FULL;

struct HandlePool
{
    uint[MAX_ENTITIES] gens;
    bool[MAX_ENTITIES] alive;
    uint[MAX_ENTITIES] free_list;   // стек освобождённых индексов
    uint free_count;
    uint next_unused;               // индексы >= next_unused ещё не выдавались
    uint live;
}

<*
 Выдать хендл: сначала из free_list (последний освобождённый — LIFO),
 иначе следующий неиспользованный индекс. Пул полон — POOL_FULL~.
*>
fn Handle? HandlePool.alloc(&self)
{
    uint index;
    if (self.free_count > 0)
    {
        index = self.free_list[--self.free_count];
    }
    else
    {
        if (self.next_unused == MAX_ENTITIES) return POOL_FULL~;
        index = self.next_unused++;
    }
    self.alive[index] = true;
    self.live++;
    return { index, self.gens[index] };
}

fn bool HandlePool.valid(&self, Handle h)
{
    return h.index < MAX_ENTITIES && self.alive[h.index] && self.gens[h.index] == h.gen;
}

<*
 Освободить хендл: мёртвый/устаревший хендл игнорируется. Поколение
 растёт, чтобы все копии старого хендла стали недействительными.
*>
fn void HandlePool.free(&self, Handle h)
{
    if (!self.valid(h)) return;
    self.alive[h.index] = false;
    self.gens[h.index]++;
    self.free_list[self.free_count++] = h.index;
    self.live--;
}

// ------------------------------------------------------ утилиты
struct Rng
{
    uint state;
}

// LCG: детерминированный и одинаковый на всех платформах.
fn uint Rng.next(&self)
{
    self.state = self.state * 1103515245 + 12345;
    return (self.state >> 16) & 0x7FFF;
}

fn int Rng.range(&self, int lo, int hi) => lo + (int)(self.next() % (uint)(hi - lo + 1));

const uint FNV_BASIS = 2166136261;

fn uint fnv_int(uint h, int v)
{
    uint u = (uint)v;
    for (int i = 0; i < 4; i++) h = (h ^ ((u >> (8 * i)) & 0xFF)) * 16777619;
    return h;
}

fn uint fnv_bytes(uint h, char[] data)
{
    foreach (b : data) h = (h ^ b) * 16777619;
    return h;
}
