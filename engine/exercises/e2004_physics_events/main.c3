// =====================================================================
//  e2004 · Итоговый проект, шаг 4: физика, broadphase и события
// =====================================================================
//
//  Добавились events.c3 (глава 06) и physics.c3 (глава 11).
//
//  Порядок тика в движке:
//
//      integrate()                       двигаем всё
//      grid = arena.alloc(Grid)          временная структура -> кадровая арена!
//      grid.build(world)                 broadphase
//      detect_collisions(world, grid, q) narrowphase -> q.push(...)
//      q.swap()                          опубликовать события тика
//      for (ev : q.read()) game.on_collision(ev)
//      world.flush()                     отложенные удаления
//      arena.reset()
//
//  Почему сетка, а не «каждый с каждым»: при N объектах это N^2/2 пар.
//  Сетка проверяет только соседей по ячейке. Программа ниже печатает
//  число проверенных пар — сравните с N^2/2.
//
//  ЗАДАЧА: реализуйте EventQueue.push и swap (events.c3), Grid.insert и
//  detect_collisions (physics.c3).
//
module mini::app;
import mini::core, mini::ecs, mini::events, mini::physics, std::io;

const uint LAYER_A = 1;
const uint LAYER_B = 2;

char[1 << 16] g_frame_mem @align(16);

fn void main()
{
    // --- очередь
    EventQueue q;
    q.push({ 1, 2 });
    assert(q.read().len == 0, "до swap событий не видно");
    q.swap();
    assert(q.read().len == 1 && q.read()[0].b == 2);
    q.push({ 3, 4 });
    q.swap();
    assert(q.read().len == 1 && q.read()[0].a == 3, "старые события пропали после swap");
    q.swap();
    assert(q.read().len == 0);

    // --- сетка
    Grid g;
    g.insert(9, 12 * core::FX, 4 * core::FX, 1 * core::FX);       // одна ячейка (1,0)
    assert(g.count[1] == 1 && g.items[1][0] == 9);
    g.insert(10, 8 * core::FX, 8 * core::FX, 1 * core::FX);       // угол: 4 ячейки
    assert(g.count[0] == 1 && g.count[1] == 2 && g.count[8] == 1 && g.count[9] == 1);
    g.insert(11, 63 * core::FX, 23 * core::FX, 3 * core::FX);     // у края: clamp
    assert(g.count[23] == 1);

    // --- сцена: 24 тела двух слоёв летают 120 тиков
    Arena arena;
    arena.init(&g_frame_mem);
    World* w = mem::new(World);
    defer free(w);
    Rng rng = { 99 };
    for (int i = 0; i < 24; i++)
    {
        Handle h = w.spawn();
        w.transforms.set(h.index, { rng.range(0, 63) * core::FX, rng.range(0, 23) * core::FX, 0 });
        w.velocities.set(h.index, { rng.range(-90, 90), rng.range(-40, 40) });
        bool a = i % 2 == 0;
        w.colliders.set(h.index, { core::FX * (a ? 2 : 1), a ? LAYER_A : LAYER_B, a ? LAYER_B : 0 });
    }
    int total_events = 0;
    int total_tests = 0;
    uint h = core::FNV_BASIS;
    for (int tick = 0; tick < 120; tick++)
    {
        physics::integrate(w);
        Grid* grid = arena.alloc(Grid::size, Grid::alignment);
        grid.build(w);
        total_tests += physics::detect_collisions(w, grid, &q);
        q.swap();
        foreach (ev : q.read())
        {
            assert(ev.a < ev.b);
            total_events++;
            h = core::fnv_int(h, tick);
            h = core::fnv_int(h, (int)ev.a);
            h = core::fnv_int(h, (int)ev.b);
        }
        arena.reset();
    }
    io::printfn("collision events=%d pair tests=%d (brute force would test %d)", total_events, total_tests, 120 * 12 * 12);
    io::printfn("events checksum=%08x, world checksum=%08x, arena peak=%d", h, w.checksum(), arena.peak);
}
