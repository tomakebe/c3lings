// =====================================================================
//  e1204 · Граф задач: зависимости и топологический порядок
// =====================================================================
//
//  Сначала прочитайте engine/docs/12_multithreading.md (раздел
//  «Зависимости и графы задач»).
//
//  Кадр движка — это не список, а граф: анимация нужна скиннингу,
//  физика — отсечению, отсечение — рендеру, а ИИ и аудио могут идти
//  параллельно со всем остальным:
//
//          input
//         /  |  \
//      anim  ai  audio
//        |    \
//      skin   physics
//         \   /
//         cull
//           |
//        render
//
//  Как это исполняется (так устроены TaskFlow, Unity Job System,
//  frame graph'ы во многих движках):
//
//   1. «Компиляция» графа — один раз: по спискам зависимостей строим
//      обратные рёбра (successors) и проверяем, что нет циклов
//      (алгоритм Кана). Заодно получаем топологический порядок — им
//      удобно отлаживать и исполнять граф в однопоточном режиме.
//   2. Запуск: у каждой задачи атомарный счётчик pending = число её
//      зависимостей. Задачи с pending == 0 сразу кладутся в очередь.
//   3. Когда задача завершилась, она уменьшает pending у каждого
//      последователя. Тот, кто довёл счётчик до нуля, и кладёт
//      последователя в очередь — ровно один раз, без мьютекса на граф.
//
//          pending(cull) = 2
//          skin    done ──sub(1)──► 1      (ничего не делаем)
//          physics done ──sub(1)──► 0  ──► push(cull)
//
//  Atomic.sub возвращает СТАРОЕ значение: «довёл до нуля» значит
//  `sub(1) == 1`.
//
//  ЗАДАЧА:
//    1. TaskGraph.compile — построить successors, проверить цикл и
//       заполнить order алгоритмом Кана. Чтобы порядок был
//       детерминированным, среди готовых всегда берите задачу с
//       наименьшим индексом.
//    2. TaskGraph.on_task_done — освободить последователей.
//
import std::io, std::thread, std::atomic;

const MAX_TASKS = 16;
const MAX_DEPS = 4;

struct Task
{
    String name;
    long base;                     // «собственная работа» задачи
    int[MAX_DEPS] deps;
    int dep_count;
    // заполняется в compile():
    int[MAX_TASKS] successors;
    int succ_count;
    // состояние исполнения:
    Atomic{int} pending;
    Atomic{bool} done;
    long value;                    // результат = base + сумма value зависимостей
}

struct TaskGraph
{
    Task[MAX_TASKS] tasks;
    int count;
    int[MAX_TASKS] order;          // топологический порядок (заполняет compile)

    // очередь готовых задач (готово)
    Mutex mtx;
    ConditionVariable cv;
    int[MAX_TASKS] ready;
    int ready_head, ready_tail;
    int in_flight;                 // взято из очереди, но ещё не завершено
    bool quitting;
    Atomic{int} remaining;         // сколько задач ещё не выполнено
}

fn int TaskGraph.add(&self, String name, long base, int[] deps = {})
{
    assert(self.count < MAX_TASKS && deps.len <= MAX_DEPS);
    Task* t = &self.tasks[self.count];
    t.name = name;
    t.base = base;
    foreach (i, d : deps) t.deps[i] = d;
    t.dep_count = (int)deps.len;
    return self.count++;
}

// Построить successors и топологический порядок. false — если есть цикл.
fn bool TaskGraph.compile(&self)
{
    // TODO:
    //   1. Обнулить succ_count у всех задач, затем для каждой задачи i и
    //      каждой её зависимости d дописать i в d.successors.
    //   2. Алгоритм Кана: indegree[i] = dep_count; повторить count раз:
    //      найти НЕвыведенную задачу с indegree == 0 и наименьшим индексом
    //      (не нашли — цикл, вернуть false), записать её в order[n],
    //      уменьшить indegree у её последователей.
    //   3. Вернуть true.
    return false;
}

fn void TaskGraph.push_ready(&self, int idx)
{
    self.mtx.lock();
    self.ready[self.ready_tail++ % MAX_TASKS] = idx;
    self.cv.signal();
    self.mtx.unlock();
}

// Вызывается рабочим потоком после выполнения задачи idx.
fn void TaskGraph.on_task_done(&self, int idx)
{
    // TODO: для каждого последователя s задачи idx атомарно уменьшить
    //       tasks[s].pending; если именно этот вызов довёл его до нуля
    //       (sub вернул 1) — self.push_ready(s).
}

// ------------------------------------------------ исполнение (готово)

fn void TaskGraph.execute(&self, int idx)
{
    Task* t = &self.tasks[idx];
    long v = t.base;
    for (int k = 0; k < t.dep_count; k++)
    {
        Task* d = &self.tasks[t.deps[k]];
        assert(d.done.load(), "task '%s' started before its dependency '%s' finished", t.name, d.name);
        v += d.value;
    }
    t.value = v;
    t.done.store(true);
}

fn int graph_worker(void* arg)
{
    TaskGraph* g = arg;
    while (true)
    {
        g.mtx.lock();
        while (g.ready_head == g.ready_tail && !g.quitting) g.cv.wait(&g.mtx);
        if (g.ready_head == g.ready_tail) { g.mtx.unlock(); return 0; }
        int idx = g.ready[g.ready_head++ % MAX_TASKS];
        g.in_flight++;
        g.mtx.unlock();

        g.execute(idx);
        g.remaining.sub(1);
        g.on_task_done(idx);

        g.mtx.lock();
        g.in_flight--;
        // Всё сделано — или делать больше нечего (граф «застрял»).
        if (g.remaining.load() == 0 || (g.in_flight == 0 && g.ready_head == g.ready_tail))
        {
            g.quitting = true;
            g.cv.broadcast();
        }
        g.mtx.unlock();
    }
}

// Выполнить граф на `workers` потоках. false — если граф застрял.
fn bool TaskGraph.run(&self, int workers)
{
    self.mtx.init()!!;
    self.cv.init()!!;
    defer { self.cv.destroy(); self.mtx.destroy(); }
    self.ready_head = self.ready_tail = 0;
    self.in_flight = 0;
    self.quitting = false;
    self.remaining.store(self.count);
    for (int i = 0; i < self.count; i++)
    {
        self.tasks[i].pending.store(self.tasks[i].dep_count);
        self.tasks[i].done.store(false);
        self.tasks[i].value = 0;
    }
    for (int i = 0; i < self.count; i++)
    {
        if (self.tasks[i].dep_count == 0) self.push_ready(i);
    }
    Thread[8] ts;
    for (int i = 0; i < workers; i++) ts[i].create(&graph_worker, self)!!;
    for (int i = 0; i < workers; i++) ts[i].join()!!;
    return self.remaining.load() == 0;
}

fn void main()
{
    TaskGraph g;
    int input   = g.add("input", 1);
    int anim    = g.add("anim", 10, { input });
    int ai      = g.add("ai", 100, { input });
    int audio   = g.add("audio", 1000, { input });
    int skin    = g.add("skin", 10000, { anim });
    int physics = g.add("physics", 100000, { ai });
    int cull    = g.add("cull", 1000000, { skin, physics });
    int render  = g.add("render", 10000000, { cull, audio });

    assert(g.compile(), "frame graph has no cycles, compile() must succeed");
    assert(g.tasks[input].succ_count == 3, "input must have 3 successors");
    assert(g.tasks[cull].succ_count == 1);
    io::print("order:");
    for (int i = 0; i < g.count; i++) io::printf(" %s", g.tasks[g.order[i]].name);
    io::printn();

    // Топологический порядок обязан уважать каждое ребро.
    int[MAX_TASKS] pos;
    for (int i = 0; i < g.count; i++) pos[g.order[i]] = i;
    for (int i = 0; i < g.count; i++)
    {
        for (int k = 0; k < g.tasks[i].dep_count; k++) assert(pos[g.tasks[i].deps[k]] < pos[i]);
    }

    // Много прогонов с разным числом потоков — результат один и тот же.
    for (int rep = 0; rep < 200; rep++)
    {
        assert(g.run(1 + rep % 4), "graph stalled: some tasks never became ready");
        assert(g.tasks[render].value == 11111112 + 1, "render value %d", g.tasks[render].value);
    }
    for (int i = 0; i < g.count; i++) io::printfn("  %-8s = %d", g.tasks[i].name, g.tasks[i].value);

    // Граф с циклом: b -> c -> d -> b.
    TaskGraph bad;
    int a = bad.add("a", 1);
    int b = bad.add("b", 1, { a, 3 });
    int c = bad.add("c", 1, { b });
    bad.add("d", 1, { c });
    assert(!bad.compile(), "cycle must be detected");
    io::printn("cycle: detected");
}
