// =====================================================================
//  E0202 · Линейный аллокатор (арена)
// =====================================================================
//
//  Сначала прочитайте engine/docs/02_memory.md (разделы 2 и 4).
//
//  Арена — буфер и смещение. Выделение = выровнять смещение и сдвинуть
//  его; освобождения отдельных объектов нет, только reset() всего сразу.
//
//      buf: [####AAAA##BBBBBBBB....................]
//                              ^offset
//
//  Детали, которые отличают аккуратную арену от наивной:
//    * выравнивать надо АДРЕС (buf.ptr + offset), а не смещение: буфер
//      сам может начинаться с адреса, не кратного 64;
//    * проверка переполнения без переполнения: не `start + size > cap`
//      (сумма может переполниться при огромном size), а
//      `size > cap - start` (при start <= cap);
//    * при нехватке памяти — вернуть null, offset не трогать, failed++;
//    * peak — максимальное offset за всё время (high-water mark): по
//      нему выбирают размер буфера для релиза.
//
//  Буфер в main выровнен на 64 (`@align(64)`), поэтому смещения,
//  которые печатает программа, не зависят от адресов — вывод
//  детерминирован. (Никогда не печатайте сами указатели!)
//
//  ЗАДАЧА: реализуйте LinearArena.alloc и LinearArena.reset.
//  Макросы new/new_array уже написаны поверх alloc.
//
import std::io;

fn usz align_up(usz x, usz a) => (x + a - 1) & ~(a - 1);

struct LinearArena
{
    char[] buf;
    usz offset;
    usz peak;
    usz allocs;     // успешных выделений с последнего reset
    usz failed;     // неудачных выделений за всё время
}

fn void* LinearArena.alloc(&self, usz size, usz align)
{
    usz base = (usz)self.buf.ptr;
    usz cap = (usz)self.buf.len;
    usz start = align_up(base + self.offset, align) - base;
    if (start > cap || size > cap - start)
    {
        self.failed++;
        return null;
    }
    self.offset = start + size;
    if (self.offset > self.peak) self.peak = self.offset;
    self.allocs++;
    return self.buf.ptr + start;
}

fn void LinearArena.reset(&self)
{
    self.offset = 0;
    self.allocs = 0;
}

macro LinearArena.new(&self, $Type) => ($Type*)self.alloc($Type::size, $Type::alignment);

macro LinearArena.new_array(&self, $Type, usz n)
{
    $Type* p = self.alloc($Type::size * n, $Type::alignment);
    if (!p) return p[:0];
    return p[:n];
}

// Смещение указателя относительно начала буфера (для печати).
fn usz LinearArena.off(&self, void* p) => (usz)p - (usz)self.buf.ptr;

struct Transform { float[3] pos; float[4] rot; float scale; }
struct Big { char[100] data; }

fn void main()
{
    char[1024] storage @align(64);
    LinearArena a = { .buf = &storage };

    char* c = a.alloc(1, 1);
    int* i = a.new(int);
    double* d = a.new(double);
    void* line = a.alloc(64, 64);
    Transform[] ts = a.new_array(Transform, 3);
    assert(c && i && d && line && ts.len == 3);
    assert((usz)i % 4 == 0 && (usz)d % 8 == 0 && (usz)line % 64 == 0, "misaligned allocation");
    io::printfn("char@%d int@%d double@%d line@%d transforms@%d offset=%d",
                a.off(c), a.off(i), a.off(d), a.off(line), a.off(ts.ptr), a.offset);
    assert(a.off(i) == 4 && a.off(d) == 8 && a.off(line) == 64 && a.offset == 128 + 3 * Transform::size);

    // Объекты, выделенные подряд, лежат подряд и не перекрываются.
    foreach (k, &t : ts) t.scale = (float)k;
    *d = 2.5;
    *i = 42;
    assert(*i == 42 && *d == 2.5 && ts[2].scale == 2.0f);

    // Нехватка памяти: null, смещение не меняется.
    usz before = a.offset;
    Big[] too_many = a.new_array(Big, 100);
    assert(too_many.len == 0 && a.offset == before && a.failed == 1, "failed alloc must not move offset");
    void* huge = a.alloc(usz::max - 8, 8);    // проверка переполнения
    assert(huge == null && a.failed == 2 && a.offset == before, "overflow in bounds check");

    // Заполняем до конца ровно.
    void* rest = a.alloc(1024 - a.offset, 1);
    assert(rest != null && a.offset == 1024);
    assert(a.alloc(1, 1) == null);
    io::printfn("full: offset=%d peak=%d allocs=%d failed=%d", a.offset, a.peak, a.allocs, a.failed);

    // Сброс: вся память снова свободна, peak помнит максимум.
    a.reset();
    assert(a.offset == 0 && a.allocs == 0 && a.peak == 1024);
    int* again = a.new(int);
    assert(a.off(again) == 0, "after reset allocation starts from the beginning");

    // Типичный кадр: 10 кадров временных данных, peak показывает худший.
    for (int frame = 0; frame < 10; frame++)
    {
        a.reset();
        a.new_array(Transform, (usz)(frame * 3 % 7 + 1));
        a.alloc(16 * (usz)frame, 16);
    }
    io::printfn("after frames: offset=%d peak=%d failed=%d", a.offset, a.peak, a.failed);
    io::printn("arena OK");
}
