// =====================================================================
//  E0204 · Пул блоков фиксированного размера
// =====================================================================
//
//  Сначала прочитайте engine/docs/02_memory.md (раздел 6).
//
//  Пул режет буфер на N одинаковых блоков. Свободные блоки связаны в
//  ИНТРУЗИВНЫЙ список: указатель на следующий свободный блок хранится
//  прямо внутри свободного блока — он всё равно не используется.
//
//      блоки:      [0][1][2][3][4][5]
//      занято:      X     X
//      free_head -> 1 -> 3 -> 4 -> 5 -> null
//
//      alloc: b = free_head; free_head = b.next;    O(1)
//      free:  b.next = free_head; free_head = b;    O(1)
//
//  Требования к блоку: размер не меньше указателя (иначе некуда
//  записать next) и кратен выравниванию (чтобы каждый блок был выровнен).
//
//  Порядок выдачи детерминирован: после init блоки выдаются по
//  возрастанию номера, а освобождённый блок выдаётся первым (LIFO —
//  он «тёплый» в кэше). Тест проверяет этот порядок.
//
//  free() должен отвергать (вернуть false) указатели «не отсюда»:
//  вне буфера или не на границе блока. Это дешёвая проверка, которую
//  стоит держать даже в релизе.
//
//  ЗАДАЧА: реализуйте Pool.init (размер блока + построение списка),
//  Pool.alloc и Pool.free.
//
import std::io;

fn usz align_up(usz x, usz a) => (x + a - 1) & ~(a - 1);

struct FreeNode
{
    FreeNode* next;
}

struct Pool
{
    char* base;
    usz block_size;
    usz capacity;
    FreeNode* free_head;
    usz used;
    usz peak;
}

// Буфер buf должен быть выровнен на align.
fn void Pool.init(&self, char[] buf, usz item_size, usz align)
{
    usz bs = align_up(item_size, align);
    if (bs < FreeNode::size) bs = align_up(FreeNode::size, align);
    self.base = buf.ptr;
    self.block_size = bs;
    self.capacity = (usz)buf.len / bs;
    self.used = 0;
    self.peak = 0;
    self.free_head = null;
    // Строим список с конца, чтобы голова указывала на блок 0.
    for (usz i = self.capacity; i > 0; i--)
    {
        FreeNode* n = (FreeNode*)(self.base + (i - 1) * bs);
        n.next = self.free_head;
        self.free_head = n;
    }
}

fn void* Pool.alloc(&self)
{
    FreeNode* n = self.free_head;
    if (!n) return null;
    self.free_head = n.next;
    self.used++;
    if (self.used > self.peak) self.peak = self.used;
    return n;
}

fn bool Pool.free(&self, void* p)
{
    usz off = (usz)p - (usz)self.base;
    if ((usz)p < (usz)self.base || off >= self.capacity * self.block_size) return false;
    if (off % self.block_size != 0) return false;
    FreeNode* n = p;
    n.next = self.free_head;
    self.free_head = n;
    self.used--;
    return true;
}

fn usz Pool.index_of(&self, void* p) => ((usz)p - (usz)self.base) / self.block_size;

struct Bullet
{
    float[<2>] pos;
    float[<2>] vel;
    int owner;
    int ttl;
}

fn void main()
{
    char[1024] storage @align(16);

    // Маленькие объекты: блок не может быть меньше указателя.
    Pool tiny;
    tiny.init(&storage, 2, 2);
    assert(tiny.block_size == FreeNode::size, "block must be able to hold the free-list pointer");

    Pool p;
    p.init(&storage, Bullet::size, Bullet::alignment);
    io::printfn("block_size=%d capacity=%d", p.block_size, p.capacity);
    assert(p.block_size == 24 && p.capacity == 42);

    Bullet*[64] live;
    int n = 0;
    for (int i = 0; i < 5; i++)
    {
        Bullet* b = p.alloc();
        *b = { .owner = i, .ttl = 10 * (i + 1) };
        live[n++] = b;
    }
    io::printf("first five:");
    for (int i = 0; i < n; i++) io::printf(" %d", p.index_of(live[i]));
    io::printn();
    for (int i = 0; i < n; i++) assert(p.index_of(live[i]) == (usz)i, "fresh pool must hand out blocks in order");

    // Освобождаем 1 и 3; следующие выделения получат сначала 3, потом 1 (LIFO).
    assert(p.free(live[1]) && p.free(live[3]));
    Bullet* x = p.alloc();
    Bullet* y = p.alloc();
    Bullet* z = p.alloc();
    io::printfn("reuse order: %d %d %d", p.index_of(x), p.index_of(y), p.index_of(z));
    assert(p.index_of(x) == 3 && p.index_of(y) == 1 && p.index_of(z) == 5);
    assert(live[0].ttl == 10 && live[4].owner == 4, "live objects must not be touched");

    // Чужие указатели отвергаются.
    int outside;
    assert(!p.free(&outside), "pointer outside the pool");
    assert(!p.free((char*)x + 4), "pointer not at a block boundary");
    assert(p.used == 6);

    // Исчерпание и полное освобождение.
    while (p.alloc()) {}
    assert(p.used == p.capacity && p.peak == p.capacity);
    io::printfn("exhausted: used=%d peak=%d", p.used, p.peak);
    for (usz i = 0; i < p.capacity; i++) assert(p.free(p.base + i * p.block_size));
    assert(p.used == 0 && p.alloc() != null);

    // Симуляция: пули живут разное время, пул держит пик.
    p.init(&storage, Bullet::size, Bullet::alignment);
    n = 0;
    uint seed = 7;
    for (int frame = 0; frame < 200; frame++)
    {
        seed = seed * 1103515245 + 12345;
        int spawn = (int)((seed >> 16) % 4);
        for (int k = 0; k < spawn && n < 64; k++)
        {
            Bullet* b = p.alloc();
            if (!b) break;
            *b = { .ttl = (int)((seed >> 8) % 20) + k };
            live[n++] = b;
        }
        for (int k = 0; k < n; k++)
        {
            if (--live[k].ttl > 0) continue;
            assert(p.free(live[k]));
            live[k] = live[--n];   // swap-remove из списка живых
            k--;
        }
        assert(p.used == (usz)n);
    }
    io::printfn("simulation: alive=%d peak=%d", n, p.peak);
    io::printn("pool OK");
}
