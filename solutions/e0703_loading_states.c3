// =====================================================================
//  e0703 · Состояния загрузки, зависимости и бюджет ввода-вывода
// =====================================================================
//
//  Сначала прочитайте engine/docs/07_resources.md (разделы «Состояния
//  загрузки» и «Асинхронная загрузка»).
//
//  Загрузка ассета — не мгновенный вызов, а процесс, растянутый на кадры:
//
//      UNLOADED --request--> QUEUED --IO slot--> LOADING --IO done--+
//                                                                    |
//                         FAILED <--file missing--------------------+
//                           ^                                        |
//                           +--dep failed-- WAITING_DEPS <-----------+
//                                                |
//                                   all deps LOADED
//                                                v
//                                             LOADED
//
//  * Одновременно выполняется не более max_in_flight чтений: диск (и
//    особенно оптический/сетевой) не любит сотню параллельных запросов.
//  * Ассет становится LOADED, только когда загружены ВСЕ его зависимости
//    (материал без шейдера бесполезен). Байты самого ассета при этом
//    могут прийти раньше — он ждёт в WAITING_DEPS.
//  * Ошибка распространяется вверх: если текстура не нашлась, материал,
//    который от неё зависит, тоже FAILED. (Многие движки вместо этого
//    подставляют «заглушку» — розово-чёрную текстуру; см. главу.)
//
//  Здесь «асинхронность» моделируется тиками: у каждого ассета есть
//  io_cost — сколько тиков длится его чтение. Это та же логика, что и в
//  настоящем стриминге, только без потоков, а значит детерминированно.
//
//  ЗАДАЧА: реализуйте Loader.request и Loader.tick (TODO ниже).
//    request(i): если ассет не UNLOADED — ничего не делать (повторный
//      запрос не должен ставить его в очередь второй раз). Иначе СНАЧАЛА
//      рекурсивно запросить зависимости, ПОТОМ перевести ассет в QUEUED и
//      положить в конец очереди (зависимости начинают читаться раньше).
//    tick() — три фазы строго в таком порядке:
//      1. Все LOADING (в порядке индексов): remaining--; при 0 освободить
//         слот IO (in_flight--) и перейти в FAILED (если missing) или
//         в WAITING_DEPS.
//      2. Разрешение зависимостей: повторять проход по всем WAITING_DEPS,
//         пока что-то меняется: если какая-то зависимость FAILED -> FAILED;
//         если все LOADED -> LOADED.
//      3. Запуск чтений: пока in_flight < max_in_flight и очередь не пуста,
//         взять ассет из НАЧАЛА очереди -> LOADING, remaining = io_cost,
//         in_flight++, io_starts++.
//
import std::io;

enum LoadState : char
{
    UNLOADED,
    QUEUED,
    LOADING,
    WAITING_DEPS,
    LOADED,
    FAILED,
}

const String STATE_CHARS = ".QLWOF";   // UNLOADED QUEUED LOADING WAITING LOADED(O) FAILED

struct Asset
{
    String name;
    int io_cost;
    bool missing;          // файла нет на диске
    int[] deps;            // индексы зависимостей
    LoadState state;
    int remaining;
}

const int MAX_QUEUE = 32;

struct Loader
{
    Asset[] assets;
    int max_in_flight;
    int in_flight;
    int peak_in_flight;
    int io_starts;
    int[MAX_QUEUE] queue;
    int q_head;
    int q_tail;
}

fn void Loader.push(&self, int i) @inline
{
    assert(self.q_tail < MAX_QUEUE);
    self.queue[self.q_tail++] = i;
}

fn void Loader.request(&self, int i)
{
    Asset* a = &self.assets[i];
    if (a.state != UNLOADED) return;
    foreach (d : a.deps) self.request(d);
    a.state = QUEUED;
    self.push(i);
}

fn void Loader.tick(&self)
{
    // 1. продвигаем чтения
    foreach (&a : self.assets)
    {
        if (a.state != LOADING) continue;
        a.remaining--;
        if (a.remaining > 0) continue;
        self.in_flight--;
        a.state = a.missing ? FAILED : WAITING_DEPS;
    }
    // 2. разрешаем зависимости до неподвижной точки
    bool changed = true;
    while (changed)
    {
        changed = false;
        foreach (&a : self.assets)
        {
            if (a.state != WAITING_DEPS) continue;
            bool all_loaded = true;
            bool any_failed = false;
            foreach (d : a.deps)
            {
                LoadState ds = self.assets[d].state;
                if (ds == FAILED) any_failed = true;
                if (ds != LOADED) all_loaded = false;
            }
            if (any_failed) { a.state = FAILED; changed = true; }
            else if (all_loaded) { a.state = LOADED; changed = true; }
        }
    }
    // 3. запускаем новые чтения
    while (self.in_flight < self.max_in_flight && self.q_head < self.q_tail)
    {
        Asset* a = &self.assets[self.queue[self.q_head++]];
        a.state = LOADING;
        a.remaining = a.io_cost;
        self.in_flight++;
        self.io_starts++;
    }
}

// ---------------------------------------------------------------------
// Ниже — проверочный код, его менять не нужно.
// ---------------------------------------------------------------------

fn bool Loader.busy(&self)
{
    foreach (a : self.assets)
    {
        if (a.state == QUEUED || a.state == LOADING || a.state == WAITING_DEPS) return true;
    }
    return false;
}

fn void Loader.check_invariants(&self)
{
    assert(self.in_flight <= self.max_in_flight, "IO budget exceeded");
    if (self.in_flight > self.peak_in_flight) self.peak_in_flight = self.in_flight;
    int loading = 0;
    foreach (a : self.assets)
    {
        if (a.state == LOADING) loading++;
        if (a.state == LOADED)
        {
            foreach (d : a.deps)
            {
                assert(self.assets[d].state == LOADED,
                       "%s is LOADED before its dependency %s", a.name, self.assets[d].name);
            }
        }
    }
    assert(loading == self.in_flight, "in_flight (%d) != number of LOADING assets (%d)",
           self.in_flight, loading);
}

fn void Loader.print(&self, int tick)
{
    io::printf("tick %2d:", tick);
    foreach (a : self.assets) io::printf(" %c", STATE_CHARS[a.state.ordinal]);
    io::printfn("   in_flight=%d", self.in_flight);
}

enum Id : int
{
    VS, FS, PROG, ALBEDO, NORMAL, HERO_MAT, MISSING_TEX, BROKEN_MAT, UNUSED
}

fn void main()
{
    Asset[*] assets = {
        [Id.VS.ordinal]          = { .name = "hero.vs",     .io_cost = 1 },
        [Id.FS.ordinal]          = { .name = "hero.fs",     .io_cost = 1 },
        [Id.PROG.ordinal]        = { .name = "hero.prog",   .io_cost = 1, .deps = { 0, 1 } },
        [Id.ALBEDO.ordinal]      = { .name = "albedo.tex",  .io_cost = 4 },
        [Id.NORMAL.ordinal]      = { .name = "normal.tex",  .io_cost = 3 },
        [Id.HERO_MAT.ordinal]    = { .name = "hero.mat",    .io_cost = 1, .deps = { 2, 3, 4 } },
        [Id.MISSING_TEX.ordinal] = { .name = "missing.tex", .io_cost = 2, .missing = true },
        [Id.BROKEN_MAT.ordinal]  = { .name = "broken.mat",  .io_cost = 1, .deps = { 2, 6 } },
        [Id.UNUSED.ordinal]      = { .name = "unused.tex",  .io_cost = 5 },
    };
    Loader ld = { .assets = &assets, .max_in_flight = 2 };

    io::printn("legend: . unloaded, Q queued, L loading, W waiting deps, O loaded, F failed");
    io::printf("        ");
    foreach (a : assets) io::printf(" %c", a.name[0]);
    io::printn();

    ld.request(Id.HERO_MAT.ordinal);
    ld.request(Id.BROKEN_MAT.ordinal);
    ld.request(Id.HERO_MAT.ordinal);        // повторный запрос — без эффекта
    assert(ld.q_tail == 8, "queue must contain 8 unique assets, got %d", ld.q_tail);
    assert(ld.queue[0] == Id.VS.ordinal && ld.queue[2] == Id.PROG.ordinal,
           "dependencies must be queued before the asset that needs them");
    assert(assets[Id.UNUSED.ordinal].state == UNLOADED);

    int tick = 0;
    int hero_ready_tick = -1;
    ld.print(tick);
    while (ld.busy())
    {
        tick++;
        assert(tick < 50, "loader does not make progress");
        ld.tick();
        ld.check_invariants();
        ld.print(tick);
        if (hero_ready_tick < 0 && assets[Id.HERO_MAT.ordinal].state == LOADED) hero_ready_tick = tick;
    }

    assert(assets[Id.HERO_MAT.ordinal].state == LOADED);
    assert(assets[Id.PROG.ordinal].state == LOADED);
    assert(assets[Id.MISSING_TEX.ordinal].state == FAILED);
    assert(assets[Id.BROKEN_MAT.ordinal].state == FAILED, "failure must propagate to dependents");
    assert(assets[Id.UNUSED.ordinal].state == UNLOADED, "nobody requested unused.tex");
    assert(ld.io_starts == 8, "each asset must be read exactly once");
    assert(ld.peak_in_flight == 2, "IO budget should be fully used");
    io::printfn("hero.mat ready at tick %d, total ticks %d, io_starts=%d",
                hero_ready_tick, tick, ld.io_starts);
}
