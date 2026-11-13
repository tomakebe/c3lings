// =====================================================================
//  e2001 · Итоговый проект, шаг 1: ядро — арена и пул хендлов
// =====================================================================
//
//  Это первый из шести шагов итогового проекта (engine/docs/20_capstone.md).
//  Вы соберёте мини-движок из подсистем, которые изучили в курсе, и
//  запустите на нём headless-игру в духе Asteroids. Каждый шаг — каталог
//  с несколькими модулями; на следующем шаге ваш код (в виде решения)
//  переезжает дальше, и к нему добавляются новые модули.
//
//      шаг 1  core.c3                    арена, хендлы, утилиты    <- вы здесь
//      шаг 2  + ecs.c3                   sparse-set ECS
//      шаг 3  + loop.c3, input.c3        фиксированный шаг, ввод и реплей
//      шаг 4  + events.c3, physics.c3    коллизии, сетка, очередь событий
//      шаг 5  + render.c3, profile.c3    ASCII-растеризатор, профайлер
//      шаг 6  + game.c3                  игра целиком
//
//  Ядро — две структуры, на которых стоит всё остальное:
//
//  * Arena — кадровый аллокатор (глава 02). Всё временное за кадр
//    (сетка broadphase, списки отрисовки) берётся из арены, а в конце
//    кадра одним reset() «освобождается». Никаких free, никакой
//    фрагментации, и легко мерить бюджет: peak — максимум за игру.
//
//        base                used          cap
//        [xxxx|pad|yyyyyyyy|.................]
//                 ^ начало выровнено вверх: (used + align-1) & ~(align-1)
//
//  * HandlePool — выдача хендлов {index, gen} (глава 03). Сущность
//    удалили — поколение слота выросло, и все старые копии хендла
//    перестали быть валидными. Освобождённые индексы переиспользуются
//    в порядке LIFO (стек) — это детерминированно и кэш-дружелюбно.
//
//  ЗАДАЧА: в core.c3 реализуйте Arena.alloc, Arena.reset,
//  HandlePool.alloc, HandlePool.valid и HandlePool.free.
//  Тесты ниже проверят их и напечатают итог.
//
module mini::app;
import mini::core, std::io;

char[4096] g_backing @align(16);

fn void main()
{
    // --- арена
    Arena a;
    a.init(&g_backing);
    char* p1 = a.alloc(3, 1);
    int* p2 = a.alloc(int::size, int::alignment);
    assert(p1 != null && p2 != null, "alloc вернул null");
    assert((uptr)p2 % 4 == 0 && a.used == 8, "выравнивание: 3 байта + паддинг до 4 + 4 байта");
    void* p3 = a.alloc(10, 16);
    assert((uptr)p3 % 16 == 0 && a.used == 26);
    assert(a.alloc(5000) == null && a.failed == 1, "переполнение -> null");
    int[] arr = a.new_array(int, 100);
    arr[99] = 7;
    a.reset();
    assert(a.used == 0 && a.peak == 28 + 400, "peak помнит максимум, reset обнуляет used");
    for (int frame = 0; frame < 10; frame++)
    {
        a.new_array(long, (usz)(frame * 10 + 1));
        a.reset();
    }
    io::printfn("arena: peak=%d failed=%d", a.peak, a.failed);

    // --- хендлы
    HandlePool pool;
    Handle h0 = pool.alloc()!!;
    Handle h1 = pool.alloc()!!;
    Handle h2 = pool.alloc()!!;
    assert(h0.index == 0 && h2.index == 2 && pool.live == 3);
    pool.free(h1);
    assert(!pool.valid(h1) && pool.valid(h0) && pool.live == 2);
    pool.free(h1);                          // повторное освобождение — без эффекта
    assert(pool.live == 2, "двойной free не должен ничего ломать");
    Handle h3 = pool.alloc()!!;
    assert(h3.index == 1 && h3.gen == 1, "слот 1 переиспользован с новым поколением");
    assert(!pool.valid(h1) && pool.valid(h3), "старый хендл в новый объект не попадает");

    // заполнить до отказа
    int n = 3;
    while (true)
    {
        if (catch err = pool.alloc())
        {
            io::printfn("pool full after %d handles: %s", n, err);
            break;
        }
        n++;
    }
    assert(n == (int)core::MAX_ENTITIES);

    // перемешанная нагрузка — детерминированная контрольная сумма
    HandlePool p;
    Handle[32] hs;
    Rng rng = { 7 };
    uint h = core::FNV_BASIS;
    for (int i = 0; i < 32; i++) hs[i] = p.alloc()!!;
    for (int step = 0; step < 200; step++)
    {
        int k = rng.range(0, 31);
        if (p.valid(hs[k]))
        {
            p.free(hs[k]);
        }
        else
        {
            hs[k] = p.alloc()!!;
        }
        h = core::fnv_int(h, (int)hs[k].index);
        h = core::fnv_int(h, (int)hs[k].gen);
    }
    io::printfn("handles: live=%d checksum=%08x", p.live, h);
}
