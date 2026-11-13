// =====================================================================
//  E0302 · Handles: индекс + поколение
// =====================================================================
//
//  Сначала прочитайте engine/docs/03_containers.md (раздел 2).
//
//  Handle — 32-битное число: младшие 20 бит — индекс слота, старшие
//  12 — поколение (generation) слота на момент создания объекта.
//
//      [ generation : 12 ][ index : 20 ]
//
//  Слот хранит своё текущее поколение и флаг занятости. Handle валиден,
//  если слот занят и поколения совпадают. При удалении поколение слота
//  увеличивается — все старые handles этого слота становятся
//  недействительными (решение проблемы ABA).
//
//  Правила этой таблицы:
//    * поколения начинаются с 1, поэтому handle 0 (NULL_HANDLE)
//      никогда не валиден — нулевая инициализация = «пустая ссылка»;
//    * если поколение после увеличения дошло до GEN_LIMIT (4096), слот
//      ВЫВОДИТСЯ из оборота (retired++), а не начинает с 1: иначе
//      древний handle мог бы «ожить»;
//    * освобождённые слоты попадают в FIFO-очередь, и новый объект
//      берёт слот из очереди, только если в ней больше MIN_FREE слотов
//      (иначе берётся новый, ещё не использованный слот). Так каждый
//      слот переиспользуется как можно реже — приём из Bitsquid.
//
//  Тип handle — `typedef Handle = uint;`: это отдельный тип, его нельзя
//  случайно смешать с обычным uint (нужен явный каст).
//
//  ЗАДАЧА: реализуйте make_handle, handle_index, handle_gen,
//  HandleTable.is_valid, HandleTable.create, HandleTable.destroy.
//
import std::io;

typedef Handle = uint;

const uint INDEX_BITS = 20;
const uint INDEX_MASK = (1u << INDEX_BITS) - 1;
const uint GEN_LIMIT = 1u << (32 - INDEX_BITS);    // 4096
const Handle NULL_HANDLE = (Handle)0;

fn Handle make_handle(uint index, uint gen)
{
    return (Handle)((gen << INDEX_BITS) | (index & INDEX_MASK));
}
fn uint handle_index(Handle h)
{
    return (uint)h & INDEX_MASK;
}
fn uint handle_gen(Handle h)
{
    return (uint)h >> INDEX_BITS;
}

const uint CAP = 64;
const uint MIN_FREE = 4;

struct HandleTable
{
    uint[CAP] gen;
    bool[CAP] alive;
    uint next_unused;         // слоты >= next_unused ещё ни разу не выдавались
    uint[CAP] queue;          // кольцевая FIFO-очередь свободных слотов
    uint q_head;
    uint q_len;
    uint live;
    uint retired;
}

fn bool HandleTable.is_valid(&self, Handle h)
{
    uint i = handle_index(h);
    return i < CAP && self.alive[i] && self.gen[i] == handle_gen(h);
}

fn Handle HandleTable.create(&self)
{
    uint i;
    if (self.q_len > MIN_FREE || (self.next_unused == CAP && self.q_len > 0))
    {
        i = self.queue[self.q_head];
        self.q_head = (self.q_head + 1) % CAP;
        self.q_len--;
    }
    else if (self.next_unused < CAP)
    {
        i = self.next_unused++;
        self.gen[i] = 1;
    }
    else
    {
        return NULL_HANDLE;
    }
    self.alive[i] = true;
    self.live++;
    return make_handle(i, self.gen[i]);
}

fn bool HandleTable.destroy(&self, Handle h)
{
    if (!self.is_valid(h)) return false;
    uint i = handle_index(h);
    self.alive[i] = false;
    self.live--;
    self.gen[i]++;
    if (self.gen[i] == GEN_LIMIT)
    {
        self.retired++;
        return true;
    }
    self.queue[(self.q_head + self.q_len) % CAP] = i;
    self.q_len++;
    return true;
}

fn void main()
{
    // Упаковка.
    Handle h = make_handle(5, 3);
    assert(handle_index(h) == 5 && handle_gen(h) == 3, "pack/unpack");
    assert((uint)make_handle(INDEX_MASK, GEN_LIMIT - 1) == 0xFFFFFFFF);
    assert(handle_index(make_handle(1, 4095)) == 1 && handle_gen(make_handle(1, 4095)) == 4095);
    io::printfn("make_handle(5, 3) = 0x%08x", (uint)h);

    HandleTable t;
    assert(!t.is_valid(NULL_HANDLE), "null handle must be invalid");

    Handle a = t.create();
    Handle b = t.create();
    assert(a != NULL_HANDLE && t.is_valid(a) && t.is_valid(b));
    assert(handle_index(a) == 0 && handle_gen(a) == 1 && handle_index(b) == 1);

    // Висячий handle обнаруживается.
    assert(t.destroy(a));
    assert(!t.is_valid(a), "destroyed handle must be invalid");
    assert(!t.destroy(a), "double destroy must be rejected");

    // Отложенное переиспользование: пока в очереди <= MIN_FREE слотов,
    // выдаются новые слоты, а слот 0 «отдыхает».
    Handle[8] hs;
    for (int k = 0; k < 4; k++) hs[k] = t.create();
    io::printf("next slots:");
    for (int k = 0; k < 4; k++) io::printf(" %d", handle_index(hs[k]));
    io::printn();
    assert(handle_index(hs[0]) == 2, "slot 0 must not be reused immediately");
    for (int k = 0; k < 4; k++) t.destroy(hs[k]);   // в очереди 5 слотов: 0,2,3,4,5
    Handle c = t.create();
    io::printfn("reused slot %d gen %d", handle_index(c), handle_gen(c));
    assert(handle_index(c) == 0 && handle_gen(c) == 2, "oldest free slot is reused first, with a new generation");
    assert(!t.is_valid(a), "the old handle of slot 0 must stay invalid after reuse");

    // Переполнение поколения: каждый слот выдерживает GEN_LIMIT-1 = 4095
    // объектов, потом выводится из оборота. Создаём и удаляем объекты, пока
    // таблица не «износится» целиком.
    HandleTable w;
    Handle first = w.create();
    w.destroy(first);
    long total = 1;
    while (true)
    {
        Handle x = w.create();
        if (x == NULL_HANDLE) break;
        assert(handle_gen(x) >= 1 && handle_gen(x) < GEN_LIMIT);
        assert(w.destroy(x));
        total++;
    }
    io::printfn("table worn out after %d objects, retired=%d", total, w.retired);
    assert(w.retired == CAP && total == (long)CAP * (GEN_LIMIT - 1), "every slot must serve exactly 4095 generations");
    assert(!w.is_valid(first));
    io::printfn("live=%d retired=%d", t.live, t.retired);
    io::printn("handles OK");
}
