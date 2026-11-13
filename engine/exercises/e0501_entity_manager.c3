// =====================================================================
//  E0501 · Менеджер сущностей
// =====================================================================
//
//  Сначала прочитайте engine/docs/05_ecs.md (разделы 1–2).
//
//  В ECS сущность — это только id. Никаких данных, никаких методов.
//  Менеджер сущностей выдаёт id и отвечает на вопрос «жива ли ещё
//  сущность e?». Устроен он как таблица handles из главы 03, но без
//  ограничения ёмкости и с политикой Bitsquid:
//
//      Entity (32 бита) = [ generation : 10 ][ index : 22 ]
//
//    * generations — List{ushort}: текущее поколение каждого индекса;
//      сущность жива, если её поколение равно поколению индекса;
//    * при destroy поколение индекса увеличивается (по модулю 1024 —
//      здесь мы допускаем переполнение, но делаем его редким), а индекс
//      кладётся в FIFO-очередь свободных;
//    * create берёт индекс из очереди, только если в ней БОЛЬШЕ
//      MIN_FREE индексов; иначе заводит новый индекс (generations.push(0)).
//      Так каждый индекс переиспользуется не чаще, чем раз в MIN_FREE
//      удалений, и 10 бит поколения хватает надолго.
//
//  (Индексы List в C3 0.8.5 имеют тип sz — знаковый.)
//  Очередь — List{uint} плюс индекс головы free_head (pop_first у List
//  сдвигает весь массив — O(n)); когда голова уходит далеко, очередь
//  уплотняется (это уже написано в compact_queue).
//
//  ЗАДАЧА: реализуйте EntityManager.alive, create и destroy.
//
import std::io, std::collections::list;

typedef Entity = uint;

const uint INDEX_BITS = 22;
const uint INDEX_MASK = (1u << INDEX_BITS) - 1;
const uint GEN_MASK = (1u << (32 - INDEX_BITS)) - 1;   // 1023
const uint MIN_FREE = 1024;

fn uint entity_index(Entity e) => (uint)e & INDEX_MASK;
fn uint entity_gen(Entity e) => (uint)e >> INDEX_BITS;
fn Entity make_entity(uint index, uint gen) => (Entity)((gen << INDEX_BITS) | index);

struct EntityManager
{
    List{ushort} generations;
    List{uint} free_queue;
    sz free_head;
    usz live;
}

fn void EntityManager.init(&self, Allocator a)
{
    self.generations.init(a);
    self.free_queue.init(a);
    self.free_head = 0;
    self.live = 0;
}

fn void EntityManager.free(&self)
{
    self.generations.free();
    self.free_queue.free();
}

fn sz EntityManager.free_count(&self) => self.free_queue.len() - self.free_head;

fn void EntityManager.compact_queue(&self)
{
    if (self.free_head < 4096) return;
    sz n = self.free_count();
    for (sz i = 0; i < n; i++) self.free_queue[i] = self.free_queue[self.free_head + i];
    while (self.free_queue.len() > n) (void)self.free_queue.pop();
    self.free_head = 0;
}

fn bool EntityManager.alive(&self, Entity e)
{
    // TODO: индекс существует и поколения совпадают
    return true;
}

fn Entity EntityManager.create(&self)
{
    // TODO: из очереди (если в ней > MIN_FREE; не забудьте compact_queue)
    //       или новый индекс с поколением 0; live++
    self.live++;
    self.generations.push(0);
    return make_entity(0, 0);
}

fn bool EntityManager.destroy(&self, Entity e)
{
    // TODO: проверить, увеличить поколение (& GEN_MASK), индекс — в очередь
    self.live--;
    return true;
}

fn void main()
{
    EntityManager em;
    em.init(mem);
    defer em.free();

    Entity a = em.create();
    Entity b = em.create();
    assert(em.alive(a) && em.alive(b) && entity_index(b) == 1);
    assert(em.destroy(a) && !em.alive(a) && !em.destroy(a), "destroyed entity must be dead");
    assert(em.alive(b));
    Entity c = em.create();
    assert(entity_index(c) == 2, "index 0 must not be reused while the free queue is short");

    // Волны: создаём по 3000, уничтожаем 2/3.
    Entity[3000] wave;
    usz max_index = 0;
    int stale_hits = 0;
    for (int round = 0; round < 50; round++)
    {
        foreach (&e : wave) *e = em.create();
        for (int i = 0; i < 3000; i++)
        {
            if (i % 3 != 0) assert(em.destroy(wave[i]));
        }
        // Старые handles этой волны мертвы, даже если индексы уже переиспользованы.
        for (int i = 1; i < 3000; i += 3) if (em.alive(wave[i])) stale_hits++;
        for (int i = 0; i < 3000; i += 3) assert(em.alive(wave[i]));
        // Оставшиеся тоже уничтожаем.
        for (int i = 0; i < 3000; i += 3) em.destroy(wave[i]);
        if (round == 0) io::printfn("after round 0: indices=%d free=%d live=%d", em.generations.len(), em.free_count(), em.live);
    }
    assert(stale_hits == 0, "a destroyed entity came back to life");
    io::printfn("after 50 rounds: indices=%d free=%d live=%d", em.generations.len(), em.free_count(), em.live);
    assert(em.live == 2, "b and c are alive");
    assert(em.generations.len() < 4200, "indices must be recycled");

    // Как часто переиспользуется индекс? Максимальное поколение.
    uint max_gen = 0;
    foreach (g : em.generations) if (g > max_gen) max_gen = g;
    io::printfn("max generation %d of %d", max_gen, GEN_MASK);
    assert(max_gen < GEN_MASK, "with delayed reuse generations must not wrap here");
    io::printn("entity manager OK");
}
