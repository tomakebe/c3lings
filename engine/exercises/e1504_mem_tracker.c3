// =====================================================================
//  e1504 · Отслеживание памяти: теги, пик, отчёт об утечках
// =====================================================================
//
//  Сначала прочитайте engine/docs/15_profiling_debugging.md
//  (раздел «Отслеживание памяти»).
//
//  На консолях у игры жёсткий бюджет памяти, и вопрос «кто съел 40 МБ?»
//  задают каждую неделю. Ответ даёт отслеживающий аллокатор-обёртка:
//  он реализует тот же интерфейс `Allocator`, что и обычный, но перед
//  передачей запроса «настоящему» аллокатору ведёт учёт.
//
//  Раскладка блока: перед памятью пользователя кладём заголовок.
//
//      backing.acquire(size + 32)
//      |<------ AllocHeader (32) ------>|<------- size байт -------->|
//      | prev | next | size | id | tag  | данные пользователя         |
//      ^ raw                            ^ возвращаем raw + 32
//
//  32 байта сохраняют выравнивание 16, которое даёт malloc. (Если
//  нужно большее выравнивание — заголовок кладут с отступом, здесь мы
//  его просто запрещаем.)
//
//  Заголовки живых блоков связаны в двусвязный интрузивный список —
//  в конце уровня (или при выходе) мы проходим его и печатаем утечки
//  с id и тегом. Важно: `resize` может ПЕРЕМЕСТИТЬ блок, поэтому до
//  вызова backing.resize заголовок нужно вынуть из списка, а после —
//  вставить обратно (соседи хранят указатели на старый адрес!).
//
//  Теги. Каждый блок помечается тегом подсистемы (PHYSICS, RENDER…).
//  Текущий тег берётся с вершины стека тегов, который удобно двигать
//  scoped-макросом — тем же приёмом, что зоны профилировщика:
//
//      @mem_tag(&tracker, PHYSICS) { bodies.push(...); };
//
//  По каждому тегу считаем живые байты, их пик и число живых блоков.
//  Тег блока фиксируется при выделении и не меняется при resize.
//
//  ЗАДАЧА: реализуйте `link`, `unlink`, `acquire`, `resize`, `release`
//  у `TrackingAllocator` (TODO). Учёт: live/peak общие и по тегу,
//  count по тегу, total_allocs общий (resize не считается новым
//  выделением), id = порядковый номер выделения начиная с 1.
//
import std::io, std::collections::list;

enum MemTag : char { GENERAL, PHYSICS, RENDER, AUDIO }

struct AllocHeader
{
    AllocHeader* prev;
    AllocHeader* next;
    sz size;
    uint id;
    MemTag tag;
}

const sz HEADER = 32;

struct TagStats
{
    sz live;
    sz peak;
    int count;
}

struct TrackingAllocator (Allocator)
{
    Allocator backing;
    AllocHeader* head;            // живые блоки, новые — в голове
    uint next_id;
    MemTag[8] tag_stack;
    int tag_depth;
    TagStats[MemTag::len] tags;
    sz live;
    sz peak;
    int total_allocs;
}

fn MemTag TrackingAllocator.current_tag(&self)
    => self.tag_depth == 0 ? GENERAL : self.tag_stack[self.tag_depth - 1];
fn void TrackingAllocator.push_tag(&self, MemTag tag) => self.tag_stack[self.tag_depth++] = tag;
fn void TrackingAllocator.pop_tag(&self) => self.tag_depth--;

macro @mem_tag(TrackingAllocator* t, MemTag tag; @body)
{
    t.push_tag(tag);
    defer t.pop_tag();
    @body();
}

<* Учесть изменение живых байт тега и общего счётчика, обновить пики. *>
fn void TrackingAllocator.account(&self, MemTag tag, sz delta)
{
    TagStats* ts = &self.tags[tag.ordinal];
    ts.live += delta;
    if (ts.live > ts.peak) ts.peak = ts.live;
    self.live += delta;
    if (self.live > self.peak) self.peak = self.live;
}

<* Вставить h в голову списка живых блоков. *>
fn void TrackingAllocator.link(&self, AllocHeader* h)
{
    // TODO
}

<* Вынуть h из списка живых блоков. *>
fn void TrackingAllocator.unlink(&self, AllocHeader* h)
{
    // TODO
}

fn void*? TrackingAllocator.acquire(&self, sz size, AllocInitType init_type, sz alignment) @dynamic
{
    assert(alignment <= 16, "over-aligned allocations are not supported");
    // TODO: заголовок, id, тег, link, учёт
    return self.backing.acquire(size, init_type, alignment);
}

fn void*? TrackingAllocator.resize(&self, void* ptr, sz new_size, sz alignment) @dynamic
{
    assert(alignment <= 16, "over-aligned allocations are not supported");
    // TODO: unlink -> backing.resize -> link, учёт разницы размеров
    return self.backing.resize(ptr, new_size, alignment);
}

fn void TrackingAllocator.release(&self, void* ptr, bool aligned) @dynamic
{
    // TODO: unlink, учёт
    self.backing.release(ptr, aligned);
}

fn void TrackingAllocator.report(&self)
{
    io::printfn("live=%d peak=%d allocs=%d", self.live, self.peak, self.total_allocs);
    foreach (i, ts : self.tags)
    {
        if (ts.peak == 0) continue;
        io::printfn("  %-8s live=%d peak=%d blocks=%d", MemTag::from_ordinal(i), ts.live, ts.peak, ts.count);
    }
    for (AllocHeader* h = self.head; h; h = h.next)
    {
        io::printfn("  block #%d tag=%s size=%d", h.id, h.tag, h.size);
    }
}

// ------------------------------------------------------------ "game"
struct RigidBody { float[3] pos; float[3] vel; float mass; }
struct Texture { int w; int h; }

fn void main()
{
    TrackingAllocator t = { .backing = mem };

    List{RigidBody} bodies;
    @mem_tag(&t, PHYSICS)
    {
        bodies.init(&t);
        for (int i = 0; i < 20; i++) bodies.push({ .mass = 1 });
    };
    assert(t.tags[MemTag.PHYSICS.ordinal].count == 1, "list storage is one block");
    assert(t.tags[MemTag.PHYSICS.ordinal].live == bodies.capacity * RigidBody::size);
    assert(t.total_allocs == 1, "resize is not a new allocation");
    assert(t.current_tag() == GENERAL, "tag stack restored");

    Texture* tex;
    int[] samples;
    @mem_tag(&t, RENDER)
    {
        tex = alloc::new(&t, Texture, { 256, 256 });
        @mem_tag(&t, AUDIO)
        {
            samples = alloc::new_array(&t, int, 1000);
        };
        char* scratch = alloc::malloc(&t, 100);
        alloc::free(&t, scratch);
    };
    assert(t.tags[MemTag.RENDER.ordinal].live == Texture::size);
    assert(t.tags[MemTag.RENDER.ordinal].peak == Texture::size + 100);
    assert(t.tags[MemTag.AUDIO.ordinal].live == 4000);
    assert(t.total_allocs == 4);

    void* general = alloc::malloc(&t, 24);
    general = alloc::realloc(&t, general, 48);
    assert(t.tags[MemTag.GENERAL.ordinal].live == 48 && t.tags[MemTag.GENERAL.ordinal].count == 1);

    io::printn("== mid-level ==");
    t.report();

    bodies.free();
    alloc::free(&t, samples);
    alloc::free(&t, general);
    io::printn("== level unloaded ==");
    t.report();
    assert(t.live == Texture::size && t.head != null && t.head.id == 2 && t.head.next == null);

    alloc::free(&t, tex);
    assert(t.live == 0 && t.head == null);
    foreach (ts : t.tags) assert(ts.live == 0 && ts.count == 0);
    io::printn("== shutdown ==");
    t.report();
    io::printn("memory tracker ok");
}
