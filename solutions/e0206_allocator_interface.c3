// =====================================================================
//  E0206 · Свой аллокатор за интерфейсом Allocator
// =====================================================================
//
//  Сначала прочитайте engine/docs/02_memory.md (разделы 8–9).
//
//  Контейнеры стандартной библиотеки C3 (List, HashMap, DString, ...)
//  принимают любой `Allocator`. Если реализовать этот интерфейс для
//  своей арены с бюджетом, то вся подсистема — со всеми её списками и
//  таблицами — будет жить в своём бюджете и считать свою статистику.
//
//      interface Allocator
//      {
//          fn void*? acquire(sz size, AllocInitType init_type, sz alignment = 0);
//          fn void*? resize(void* ptr, sz new_size, sz alignment = 0);
//          fn void release(void* ptr, bool aligned);
//      }
//
//  Реализация в структуре: `struct BudgetArena (Allocator) { ... }` и
//  методы с атрибутом `@dynamic`. Передаётся как `&arena`.
//
//  Устройство нашей арены: перед каждым блоком лежит заголовок
//
//      ... [ Header{size, start} ][ данные пользователя ........ ] ...
//          ^start                ^ptr (выровнен на alignment)
//
//  где start — значение offset ДО этой аллокации. Это позволяет:
//    * release(ptr): если блок — ПОСЛЕДНИЙ (ptr + size == base + offset),
//      вернуть offset = start (память реально освобождается); иначе
//      ничего не делать (арена освобождает всё разом в reset);
//    * resize(ptr, n): если блок последний и выравнивание подходит —
//      просто сдвинуть offset (рост «на месте», без копирования!);
//      иначе acquire + копирование min(старый, новый) байт + release.
//      Именно это делает List дешёвым в арене: при удвоении ёмкости
//      данные не копируются, если между ростами никто ничего не выделял.
//
//  Правила интерфейса:
//    * alignment == 0 — значит «по умолчанию», берём DEFAULT_ALIGN (16);
//    * init_type == ZERO — обнулить память (mem::clear);
//    * нехватка бюджета — вернуть `mem::OUT_OF_MEMORY~` и failures++.
//    * Бюджет проверяется по offset: блок должен закончиться не дальше
//      budget байт от начала буфера.
//
//  ЗАДАЧА: реализуйте acquire, resize, release.
//
import std::io, std::collections::list, std::collections::map;

fn usz align_up(usz x, usz a) => (x + a - 1) & ~(a - 1);

const usz DEFAULT_ALIGN = 16;

struct Header
{
    usz size;
    usz start;
}

struct BudgetArena (Allocator)
{
    String name;
    char[] buf;
    usz budget;
    usz offset;
    usz peak;
    usz acquires;
    usz in_place;      // resize без копирования
    usz moved;         // resize с копированием
    usz reclaimed;     // release, реально вернувший память
    usz failures;
}

fn void*? BudgetArena.acquire(&self, sz size, AllocInitType init_type, sz alignment) @dynamic
{
    usz align = alignment ? (usz)alignment : DEFAULT_ALIGN;
    if (align < Header::alignment) align = Header::alignment;
    usz base = (usz)self.buf.ptr;
    usz limit = self.budget < (usz)self.buf.len ? self.budget : (usz)self.buf.len;
    usz user = align_up(base + self.offset + Header::size, align) - base;
    if (user > limit || (usz)size > limit - user)
    {
        self.failures++;
        return mem::OUT_OF_MEMORY~;
    }
    Header* h = (Header*)(self.buf.ptr + user - Header::size);
    *h = { (usz)size, self.offset };
    self.offset = user + (usz)size;
    if (self.offset > self.peak) self.peak = self.offset;
    self.acquires++;
    void* p = self.buf.ptr + user;
    if (init_type == ZERO) mem::clear(p, (usz)size);
    return p;
}

fn bool BudgetArena.is_last(&self, void* ptr)
{
    Header* h = ptr - Header::size;
    return (usz)ptr + h.size == (usz)self.buf.ptr + self.offset;
}

fn void*? BudgetArena.resize(&self, void* ptr, sz new_size, sz alignment) @dynamic
{
    usz align = alignment ? (usz)alignment : DEFAULT_ALIGN;
    Header* h = ptr - Header::size;
    if (self.is_last(ptr) && (usz)ptr % align == 0)
    {
        usz user = (usz)ptr - (usz)self.buf.ptr;
        usz limit = self.budget < (usz)self.buf.len ? self.budget : (usz)self.buf.len;
        if ((usz)new_size > limit - user)
        {
            self.failures++;
            return mem::OUT_OF_MEMORY~;
        }
        h.size = (usz)new_size;
        self.offset = user + (usz)new_size;
        if (self.offset > self.peak) self.peak = self.offset;
        self.in_place++;
        return ptr;
    }
    usz old_size = h.size;
    void* p = self.acquire(new_size, NO_ZERO, alignment)!;
    mem::copy(p, ptr, (sz)(old_size < (usz)new_size ? old_size : (usz)new_size));
    self.release(ptr, alignment != 0);
    self.moved++;
    return p;
}

fn void BudgetArena.release(&self, void* ptr, bool aligned) @dynamic
{
    if (!ptr) return;
    if (self.is_last(ptr))
    {
        Header* h = ptr - Header::size;
        self.offset = h.start;
        self.reclaimed++;
    }
}

fn void BudgetArena.reset(&self) => self.offset = 0;

fn void BudgetArena.report(&self)
{
    io::printfn("[%s] offset=%d peak=%d/%d acquires=%d in_place=%d moved=%d reclaimed=%d failures=%d",
                self.name, self.offset, self.peak, self.budget, self.acquires, self.in_place,
                self.moved, self.reclaimed, self.failures);
}

fn void main()
{
    char[32768] storage @align(64);

    // 1. Голые вызовы через интерфейс.
    BudgetArena ai = { .name = "ai", .buf = &storage, .budget = 8192 };
    Allocator a = &ai;
    int* xs = alloc::new_array(a, int, 4);
    assert(((usz)xs & 15) == 0, "default alignment is 16");
    xs[3] = 7;
    xs = alloc::realloc(a, xs, 64 * int::size);      // последний блок — растёт на месте
    assert(xs[3] == 7 && ai.in_place == 1 && ai.moved == 0);
    void* v64 = alloc::malloc_aligned(a, 10, 64)!!;
    assert(((usz)v64 & 63) == 0, "explicit alignment must be honoured");
    double* zero = alloc::new_array(a, double, 8);   // new_array обнуляет
    foreach (z : zero[:8]) assert(z == 0.0);
    xs = alloc::realloc(a, xs, 128 * int::size);     // уже не последний — копия
    assert(xs[3] == 7 && ai.moved == 1, "a non-last block must be moved and copied");
    usz before = ai.offset;
    alloc::free(a, xs);                              // xs теперь последний -> reclaimed
    assert(ai.offset < before && ai.reclaimed >= 1, "freeing the last block must reclaim memory");
    ai.report();

    // 2. Бюджет: нехватка — это Optional-ошибка, а не падение.
    void*? big = alloc::malloc_try(a, 100_000);
    if (catch err = big) io::printfn("100000 bytes from 'ai': %s", err);
    assert(ai.failures == 1);
    ai.reset();

    // 3. Стандартные контейнеры поверх нашей арены.
    BudgetArena gameplay = { .name = "gameplay", .buf = &storage, .budget = 32768 };
    List{int} ids;
    ids.init(&gameplay);
    for (int i = 0; i < 1000; i++) ids.push(i * 3);
    assert(ids.len() == 1000 && ids[999] == 2997);
    assert(gameplay.moved == 0, "a lone growing List must grow in place");
    gameplay.report();

    HashMap{int, int} hp;
    hp.init(&gameplay);
    for (int i = 0; i < 50; i++) hp.set(i, 100 - i);
    assert(hp.get(10)!! == 90 && hp.len() == 50);
    // Теперь List не последний: дальнейший рост — с копированием.
    for (int i = 0; i < 1000; i++) ids.push(i);
    assert(gameplay.moved >= 1 && ids[1500] == 500 && ids[10] == 30);
    gameplay.report();
    io::printn("allocator interface OK");
}
