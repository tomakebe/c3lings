// =====================================================================
//  e1205 · Кража работы (work stealing) и false sharing
// =====================================================================
//
//  Сначала прочитайте engine/docs/12_multithreading.md (разделы
//  «Work stealing» и «False sharing»).
//
//  Одна общая очередь из e1201 — узкое место: все потоки дерутся за
//  один мьютекс (и одну кеш-линию). Планировщики TBB, Cilk, Rust rayon,
//  .NET и многих движков дают КАЖДОМУ рабочему свою двустороннюю
//  очередь (deque):
//
//         top (thieves steal here, FIFO)
//          ▼
//        [ t0 t1 t2 t3 t4 ]
//                       ▲
//                       bottom (owner pushes/pops here, LIFO)
//
//   * Владелец кладёт и снимает задачи СНИЗУ (LIFO): только что
//     порождённая задача работает с горячими в кеше данными.
//   * Когда своя очередь пуста, поток становится вором и забирает
//     задачу СВЕРХУ у кого-то другого (FIFO): сверху лежат самые старые
//     и обычно самые крупные куски работы — украсть их выгоднее всего.
//   * Владелец и вор работают с разных концов, поэтому в lock-free
//     версии (Chase–Lev deque) они почти не конфликтуют. У нас для
//     простоты каждая deque под своим мьютексом — но мьютексов уже N,
//     и большую часть времени каждый трогает только свой.
//
//  Второй сюжет — false sharing. Статистика рабочих лежит в массиве:
//
//      struct WorkerStats { long executed; long stolen; }   // 16 байт
//      WorkerStats[4]  ->  все 4 элемента в ОДНОЙ 64-байтной кеш-линии
//
//  Каждый поток пишет только в свой элемент, гонки данных нет, но
//  линия кеша прыгает между ядрами при каждой записи — код
//  замедляется в разы. Лечится выравниванием до размера линии:
//  `struct WorkerStats @align(64) { ... }` — теперь каждый элемент
//  занимает свою линию.
//
//  ЗАДАЧА (всё помечено TODO):
//    1. WorkDeque.pop_bottom и WorkDeque.steal_top.
//    2. try_steal — обойти чужие очереди, начиная с (id + 1).
//    3. Убрать false sharing у WorkerStats.
//  Сначала main проверит всё в одном потоке, потом запустит 4 рабочих.
//
import std::io, std::thread, std::atomic;

const usz DEQUE_CAP = 4096;
const MAX_WORKERS = 4;

struct WorkDeque
{
    Mutex mtx;
    int[DEQUE_CAP] items;
    usz top;    // самый старый элемент
    usz bottom; // за самым новым; элементы живут в [top, bottom)
}

fn void WorkDeque.init(&self) => self.mtx.init()!!;
fn void WorkDeque.destroy(&self) => self.mtx.destroy();

fn void WorkDeque.push_bottom(&self, int item)
{
    self.mtx.lock();
    assert(self.bottom - self.top < DEQUE_CAP, "deque overflow");
    self.items[self.bottom % DEQUE_CAP] = item;
    self.bottom++;
    self.mtx.unlock();
}

// Владелец: снять САМЫЙ НОВЫЙ элемент (LIFO).
fn bool WorkDeque.pop_bottom(&self, int* out)
{
    self.mtx.lock();
    defer self.mtx.unlock();
    if (self.bottom == self.top) return false;
    self.bottom--;
    *out = self.items[self.bottom % DEQUE_CAP];
    return true;
}

// Вор: забрать САМЫЙ СТАРЫЙ элемент (FIFO).
fn bool WorkDeque.steal_top(&self, int* out)
{
    self.mtx.lock();
    defer self.mtx.unlock();
    if (self.bottom == self.top) return false;
    *out = self.items[self.top % DEQUE_CAP];
    self.top++;
    return true;
}

// Каждый поток пишет только в свой элемент массива статистики.
struct WorkerStats @align(64)
{
    long executed;
    long stolen;
}

struct Scheduler
{
    WorkDeque[MAX_WORKERS] deques;
    WorkerStats[MAX_WORKERS] stats;
    int worker_count;
    Atomic{int} remaining;
    long[4096] results;
}

Scheduler sched; // глобальный: структура большая для стека

// Попробовать украсть задачу у других рабочих. Обходим жертв по кругу,
// начиная с (id + 1) % worker_count, себя пропускаем. При успехе
// увеличиваем stats[id].stolen.
fn bool try_steal(Scheduler* s, int id, int* out)
{
    for (int k = 1; k < s.worker_count; k++)
    {
        int victim = (id + k) % s.worker_count;
        if (s.deques[victim].steal_top(out))
        {
            s.stats[id].stolen++;
            return true;
        }
    }
    return false;
}

// ------------------------------------------------ задачи (готово)
//
// Задача с id = root * 64 + 0 — «корневая»: она порождает 63 дочерних
// root * 64 + 1 .. root * 64 + 63 в СВОЮ очередь (как порождала бы
// подзадачи настоящая игровая система). Вся работа сначала лежит у
// рабочего 0 — остальным придётся воровать.

const ROOTS = 64;
const FANOUT = 64;

fn long heavy(int id)
{
    ulong h = (ulong)id * 0x9E3779B97F4A7C15;
    for (int i = 0; i < 300; i++) h = (h ^ (h >> 29)) * 0xBF58476D1CE4E5B9;
    return (long)(h % 1000);
}

fn void execute(Scheduler* s, int worker, int job)
{
    if (job % FANOUT == 0)
    {
        for (int k = 1; k < FANOUT; k++) s.deques[worker].push_bottom(job + k);
    }
    s.results[job] = heavy(job);
    s.stats[worker].executed++;
    s.remaining.sub(1);
}

struct WorkerCtx
{
    Scheduler* s;
    int id;
}

fn int worker_main(void* arg)
{
    WorkerCtx* ctx = arg;
    Scheduler* s = ctx.s;
    int job;
    while (s.remaining.load() > 0)
    {
        if (s.deques[ctx.id].pop_bottom(&job) || try_steal(s, ctx.id, &job))
        {
            execute(s, ctx.id, job);
        }
        else
        {
            thread::yield();
        }
    }
    return 0;
}

fn void reset(Scheduler* s, int workers)
{
    s.worker_count = workers;
    for (int i = 0; i < MAX_WORKERS; i++)
    {
        s.deques[i].top = s.deques[i].bottom = 0;
        s.stats[i] = {};
    }
}

fn void main()
{
    for (int i = 0; i < MAX_WORKERS; i++) sched.deques[i].init();
    defer for (int i = 0; i < MAX_WORKERS; i++) sched.deques[i].destroy();

    // 1) Семантика deque в одном потоке.
    {
        WorkDeque* d = &sched.deques[0];
        for (int i = 1; i <= 5; i++) d.push_bottom(i);
        int a, b, c, e;
        assert(d.pop_bottom(&a) && a == 5, "pop_bottom must return the newest item");
        assert(d.steal_top(&b) && b == 1, "steal_top must return the oldest item");
        assert(d.steal_top(&c) && c == 2);
        assert(d.pop_bottom(&e) && e == 4);
        int f;
        assert(d.pop_bottom(&f) && f == 3);
        assert(!d.pop_bottom(&f) && !d.steal_top(&f), "deque must be empty now");
        io::printfn("deque: pop_bottom=%d steal_top=%d steal_top=%d pop_bottom=%d pop_bottom=%d", a, b, c, e, f);
    }

    // 2) Порядок обхода жертв в try_steal.
    {
        reset(&sched, 4);
        sched.deques[2].push_bottom(20);
        sched.deques[2].push_bottom(21);
        sched.deques[0].push_bottom(1);
        int got;
        assert(try_steal(&sched, 1, &got) && got == 20, "worker 1 must try victim 2 first and take its top");
        assert(try_steal(&sched, 3, &got) && got == 1, "worker 3 must try victim 0 first");
        assert(try_steal(&sched, 2, &got) == false, "worker 2 must not steal from itself");
        assert(sched.stats[1].stolen == 1 && sched.stats[3].stolen == 1 && sched.stats[2].stolen == 0);
        int x;
        assert(sched.deques[2].pop_bottom(&x) && x == 21);
        io::printn("try_steal: victims visited in order, self skipped");
    }

    // 3) Раскладка: каждый элемент статистики в своей кеш-линии.
    assert(WorkerStats::alignment >= 64, "WorkerStats must be aligned to a cache line");
    assert((usz)&sched.stats[1] - (usz)&sched.stats[0] >= 64);
    io::printfn("stats: size %d, align %d", WorkerStats::size, WorkerStats::alignment);

    // 4) Настоящий прогон: 4 рабочих, вся работа сначала у рабочего 0.
    long expected = 0;
    for (int j = 0; j < ROOTS * FANOUT; j++) expected += heavy(j);
    for (int rep = 0; rep < 20; rep++)
    {
        reset(&sched, 4);
        sched.results[..] = 0;
        sched.remaining.store(ROOTS * FANOUT);
        for (int r = 0; r < ROOTS; r++) sched.deques[0].push_bottom(r * FANOUT);
        WorkerCtx[MAX_WORKERS] ctx;
        Thread[MAX_WORKERS] ts;
        for (int i = 0; i < 4; i++)
        {
            ctx[i] = { &sched, i };
            ts[i].create(&worker_main, &ctx[i])!!;
        }
        for (int i = 0; i < 4; i++) ts[i].join()!!;

        long total = 0;
        long executed = 0;
        foreach (r : sched.results) total += r;
        for (int i = 0; i < 4; i++) executed += sched.stats[i].executed;
        assert(executed == ROOTS * FANOUT, "executed %d jobs", executed);
        assert(total == expected, "checksum mismatch");
    }
    io::printfn("run: %d jobs x 20 runs, checksum %d", ROOTS * FANOUT, expected);
}
