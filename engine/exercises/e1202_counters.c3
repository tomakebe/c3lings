// =====================================================================
//  e1202 · Счётчики и ожидание с помощью (Naughty Dog style)
// =====================================================================
//
//  Сначала прочитайте engine/docs/12_multithreading.md (раздел
//  «Счётчики вместо future»).
//
//  В e1201 мы умели только «отправить всё и остановить пул». Движку
//  нужно другое: внутри кадра (и даже внутри задачи!) запустить пачку
//  задач и дождаться именно их. В движке Naughty Dog (GDC 2015,
//  Christian Gyrling) для этого служат атомарные СЧЁТЧИКИ:
//
//      Counter c;
//      js.run_jobs(batch, &c);     // c += batch.len, задачи уходят в очередь
//      js.wait_for_counter(&c);    // вернётся, когда c == 0
//
//  Каждая задача знает свой счётчик и после выполнения уменьшает его.
//  Один счётчик на пачку — дешевле, чем future на каждую задачу.
//
//  Порядок важен: счётчик нужно увеличить ДО того, как задача попадёт в
//  очередь. Иначе быстрый рабочий может выполнить её и уменьшить
//  счётчик раньше, чем мы его увеличили, — ожидающий увидит 0 и уйдёт
//  раньше времени.
//
//  Главная ловушка — ожидание ВНУТРИ задачи. Если рабочий просто
//  крутится `while (c != 0) yield();`, он занят, но ничего не делает.
//  Когда все рабочие так ждут детей, которые лежат в очереди, — это
//  взаимная блокировка (deadlock):
//
//      worker0: wait(children of A)   ─┐
//      worker1: wait(children of B)   ─┤  очередь: [A1 A2 B1 B2]  — их некому выполнить
//                                      ┘
//
//  Naughty Dog решают это файберами: ожидающая задача «паркуется», а
//  поток берёт другую. Без файберов есть простой и честный приём —
//  ожидание с помощью (help while waiting): пока счётчик не обнулился,
//  ожидающий сам достаёт задачи из очереди и выполняет их.
//
//  ЗАДАЧА: реализуйте execute_job, JobSystem.run_jobs и
//  JobSystem.wait_for_counter (TODO). Рекурсивная параллельная сумма
//  в main запускается на ДВУХ рабочих с глубокой вложенностью ожиданий —
//  без помощи при ожидании она зависнет.
//
import std::io, std::thread, std::atomic;

alias JobFn = fn void(void* data);

struct Counter
{
    Atomic{int} value;
}

struct Job
{
    JobFn func;
    void* data;
    Counter* counter; // может быть null
}

const usz QUEUE_CAP = 2048;

struct JobSystem
{
    Mutex mtx;
    ConditionVariable has_work;
    Job[QUEUE_CAP] ring;
    usz head, tail;
    bool quitting;
    Thread[8] threads;
    int worker_count;
    Atomic{int} executed; // статистика: сколько задач выполнено всего
}

// ------------------------------------------------ очередь (готово, из e1201)

fn void JobSystem.push(&self, Job job)
{
    self.mtx.lock();
    assert(self.tail - self.head < QUEUE_CAP, "job queue overflow");
    self.ring[self.tail % QUEUE_CAP] = job;
    self.tail++;
    self.has_work.signal();
    self.mtx.unlock();
}

// Неблокирующее извлечение: false, если очередь пуста.
fn bool JobSystem.try_pop(&self, Job* out)
{
    self.mtx.lock();
    defer self.mtx.unlock();
    if (self.head == self.tail) return false;
    *out = self.ring[self.head % QUEUE_CAP];
    self.head++;
    return true;
}

// Блокирующее извлечение для рабочих потоков.
fn bool JobSystem.wait_pop(&self, Job* out)
{
    self.mtx.lock();
    defer self.mtx.unlock();
    while (self.head == self.tail && !self.quitting) self.has_work.wait(&self.mtx);
    if (self.head == self.tail) return false;
    *out = self.ring[self.head % QUEUE_CAP];
    self.head++;
    return true;
}

// ------------------------------------------------ ядро: счётчики

// Выполнить задачу и отметить её завершение в счётчике (если он есть).
fn void execute_job(JobSystem* js, Job job)
{
    // TODO: вызвать job.func(job.data); увеличить js.executed на 1;
    //       если job.counter != null — уменьшить его на 1.
    //       (Полезная проверка: sub() возвращает старое значение,
    //        и оно обязано быть > 0.)
}

// Запустить пачку задач; каждой проставить counter, увеличить его ДО push.
fn void JobSystem.run_jobs(&self, Job[] jobs, Counter* counter)
{
    // TODO: сначала увеличить counter на jobs.len (одним add),
    //       затем каждой задаче проставить .counter и положить её через self.push().
}

// Ждать обнуления счётчика, выполняя чужие задачи из очереди.
fn void JobSystem.wait_for_counter(&self, Counter* counter)
{
    // TODO: пока counter не равен 0 — пытаться достать задачу через
    //       self.try_pop() и выполнить её execute_job(); если очередь
    //       пуста — thread::yield().
}

// ------------------------------------------------ рабочие потоки (готово)

fn int worker_main(void* arg)
{
    JobSystem* js = arg;
    Job job;
    while (js.wait_pop(&job)) execute_job(js, job);
    return 0;
}

fn void JobSystem.start(&self, int workers)
{
    self.mtx.init()!!;
    self.has_work.init()!!;
    self.worker_count = workers;
    for (int i = 0; i < workers; i++) self.threads[i].create(&worker_main, self)!!;
}

fn void JobSystem.stop(&self)
{
    self.mtx.lock();
    self.quitting = true;
    self.has_work.broadcast();
    self.mtx.unlock();
    for (int i = 0; i < self.worker_count; i++) self.threads[i].join()!!;
    self.has_work.destroy();
    self.mtx.destroy();
}

// ------------------------------------------------ тест 1: плоская пачка

struct SquareJob
{
    int input;
    int output;
}

fn void square_job(void* data)
{
    SquareJob* j = data;
    j.output = j.input * j.input;
}

// ------------------------------------------------ тест 2: рекурсивная сумма

const usz LEAF_SIZE = 128;

struct SumJob
{
    JobSystem* js;
    int[] values;
    long result;
}

fn void sum_job(void* data)
{
    SumJob* j = data;
    if (j.values.len <= LEAF_SIZE)
    {
        long s = 0;
        foreach (v : j.values) s += v;
        j.result = s;
        return;
    }
    // Делим пополам, запускаем две дочерние задачи и ЖДЁМ их внутри задачи.
    usz mid = j.values.len / 2;
    SumJob left = { j.js, j.values[:mid], 0 };
    SumJob right = { j.js, j.values[mid..], 0 };
    Job[2] kids = { { &sum_job, &left, null }, { &sum_job, &right, null } };
    Counter c;
    j.js.run_jobs(&kids, &c);
    j.js.wait_for_counter(&c);
    j.result = left.result + right.result;
}

fn void main()
{
    JobSystem js;
    js.start(2);

    // 1) Плоская пачка из 1000 задач, ждём из главного потока.
    SquareJob[1000] sq;
    Job[1000] batch;
    for (int i = 0; i < 1000; i++)
    {
        sq[i].input = i;
        batch[i] = { &square_job, &sq[i], null };
    }
    Counter c1;
    js.run_jobs(&batch, &c1);
    js.wait_for_counter(&c1);
    assert(c1.value.load() == 0);
    long sum_sq = 0;
    for (int i = 0; i < 1000; i++)
    {
        assert(sq[i].output == i * i, "square %d not computed", i);
        sum_sq += sq[i].output;
    }
    io::printfn("batch: 1000 jobs, sum of squares %d", sum_sq);

    // 2) Рекурсивная сумма: дерево задач с ожиданием внутри задач.
    int[] values = mem::new_array(int, 1 << 16);
    defer free(values);
    long expected = 0;
    foreach (i, &v : values)
    {
        *v = (int)((i * 7919) % 1000);
        expected += *v;
    }
    int before = js.executed.load();
    SumJob root = { &js, values, 0 };
    Job[1] root_job = { { &sum_job, &root, null } };
    Counter c2;
    js.run_jobs(&root_job, &c2);
    js.wait_for_counter(&c2);
    assert(root.result == expected, "parallel sum %d != %d", root.result, expected);
    int tree_jobs = js.executed.load() - before;
    // 65536 / 128 = 512 листьев => 1023 узла дерева
    assert(tree_jobs == 1023, "expected 1023 jobs in the tree, got %d", tree_jobs);
    io::printfn("tree: sum %d over %d jobs", root.result, tree_jobs);

    js.stop();
    io::printfn("total executed: %d", js.executed.load());
}
