// =====================================================================
//  e1201 · Пул потоков и очередь задач
// =====================================================================
//
//  Сначала прочитайте engine/docs/12_multithreading.md (разделы
//  «Потоки против задач» и «Очередь задач»).
//
//  Движок не создаёт поток на каждую задачу: создание потока стоит
//  десятки микросекунд, а задач за кадр — тысячи. Вместо этого при
//  старте поднимается пул рабочих потоков (обычно «ядер минус один»),
//  и они в цикле достают задачи из общей очереди:
//
//      main ──push──►  [ J J J J . . . ]  ──pop──► worker 0
//                         кольцевой буфер ──pop──► worker 1
//                                         ──pop──► worker 2
//
//  Задача (job) — это просто пара «указатель на функцию + указатель на
//  данные». Никаких замыканий, никаких аллокаций на задачу:
//
//      alias JobFn = fn void(void* data);
//      struct Job { JobFn func; void* data; }
//
//  Очередь ограниченной ёмкости защищена мьютексом и двумя условными
//  переменными:
//    * `not_empty` — на ней спят рабочие, когда задач нет;
//    * `not_full`  — на ней спит производитель, когда буфер полон
//      (backpressure: нельзя молча терять задачи или расти бесконечно).
//
//  Классический шаблон ожидания на условной переменной — ВСЕГДА в цикле:
//
//      self.mtx.lock();
//      while (!условие) self.cv.wait(&self.mtx);   // wait отпускает мьютекс
//      ... работаем с данными под мьютексом ...
//      self.mtx.unlock();
//
//  `while`, а не `if`: бывают ложные пробуждения, а между signal и
//  пробуждением другой поток мог уже забрать задачу.
//
//  Завершение пула (shutdown): под мьютексом ставим флаг `quitting`
//  и будим ВСЕХ (`broadcast`). Рабочий выходит, только когда очередь
//  пуста И стоит флаг — то есть уже отправленные задачи доделываются.
//
//  ЗАДАЧА: реализуйте JobQueue.push, JobQueue.pop и JobQueue.shutdown
//  (места помечены TODO). Программа сама проверит себя и напечатает
//  итоги. Обратите внимание: печатаем только после join — порядок
//  выполнения задач между потоками не детерминирован, а результат — да.
//
import std::io, std::thread;

alias JobFn = fn void(void* data);

struct Job
{
    JobFn func;
    void* data;
}

const usz QUEUE_CAP = 16; // специально маленькая: производитель будет упираться в not_full

struct JobQueue
{
    Mutex mtx;
    ConditionVariable not_empty;
    ConditionVariable not_full;
    Job[QUEUE_CAP] ring;
    usz head;      // индекс следующей задачи на извлечение (растёт бесконечно)
    usz tail;      // индекс следующего свободного места (растёт бесконечно)
    bool quitting;
}

fn void JobQueue.init(&self)
{
    self.mtx.init()!!;
    self.not_empty.init()!!;
    self.not_full.init()!!;
}

fn void JobQueue.destroy(&self)
{
    self.not_full.destroy();
    self.not_empty.destroy();
    self.mtx.destroy();
}

fn usz JobQueue.count(&self) => self.tail - self.head;

// Положить задачу. Если очередь полна — ждать на not_full.
fn void JobQueue.push(&self, Job job)
{
    // TODO: захватить мьютекс; пока очередь полна (count() == QUEUE_CAP) —
    //       ждать на not_full; записать задачу в ring[tail % QUEUE_CAP],
    //       сдвинуть tail, разбудить одного рабочего (not_empty.signal()),
    //       отпустить мьютекс.
}

// Достать задачу. Блокируется, пока очередь пуста и не идёт завершение.
// Возвращает false, только если очередь пуста И quitting == true.
fn bool JobQueue.pop(&self, Job* out)
{
    // TODO: захватить мьютекс (удобно сразу написать defer unlock);
    //       пока очередь пуста и нет quitting — ждать на not_empty;
    //       если очередь всё ещё пуста — значит, завершение: вернуть false;
    //       иначе забрать ring[head % QUEUE_CAP], сдвинуть head,
    //       разбудить производителя (not_full.signal()) и вернуть true.
    return false;
}

// Попросить рабочих завершиться, когда задачи кончатся.
fn void JobQueue.shutdown(&self)
{
    // TODO: под мьютексом выставить quitting и разбудить ВСЕХ рабочих.
}

// ------------------------------------------------------------ пул потоков

const MAX_WORKERS = 8;

struct ThreadPool
{
    JobQueue queue;
    Thread[MAX_WORKERS] threads;
    int worker_count;
}

fn int worker_main(void* arg)
{
    JobQueue* q = arg;
    Job job;
    int executed = 0;
    while (q.pop(&job))
    {
        job.func(job.data);
        executed++;
    }
    return executed; // вернётся из join — это детерминированный способ собрать статистику
}

fn void ThreadPool.start(&self, int workers)
{
    assert(workers > 0 && workers <= MAX_WORKERS);
    self.queue.init();
    self.worker_count = workers;
    for (int i = 0; i < workers; i++) self.threads[i].create(&worker_main, &self.queue)!!;
}

fn void ThreadPool.submit(&self, JobFn func, void* data) => self.queue.push({ func, data });

// Дождаться выполнения всех задач и остановить потоки. Возвращает число выполненных задач.
fn int ThreadPool.stop(&self)
{
    self.queue.shutdown();
    int total = 0;
    for (int i = 0; i < self.worker_count; i++) total += self.threads[i].join()!!;
    self.queue.destroy();
    return total;
}

// ------------------------------------------------------------ задачи для теста

struct CollatzJob
{
    long start;
    int steps; // результат
}

fn int collatz_steps(long n)
{
    int steps = 0;
    while (n != 1)
    {
        n = (n % 2 == 0) ? n / 2 : 3 * n + 1;
        steps++;
    }
    return steps;
}

fn void collatz_job(void* data)
{
    CollatzJob* j = data;
    j.steps = collatz_steps(j.start);
}

// Для теста порядка: каждая задача дописывает свой номер в общий журнал.
struct OrderLog
{
    int[64] ids;
    int len;
}

struct OrderJob
{
    OrderLog* log;
    int id;
}

fn void order_job(void* data)
{
    OrderJob* j = data;
    j.log.ids[j.log.len++] = j.id; // без мьютекса: корректно ТОЛЬКО при одном рабочем!
}

fn void main()
{
    // 1) Один рабочий: очередь обязана быть FIFO.
    {
        ThreadPool pool;
        OrderLog log;
        OrderJob[40] jobs;
        pool.start(1);
        for (int i = 0; i < 40; i++)
        {
            jobs[i] = { &log, i };
            pool.submit(&order_job, &jobs[i]);
        }
        int done = pool.stop();
        assert(done == 40, "expected 40 jobs, got %d", done);
        assert(log.len == 40);
        for (int i = 0; i < 40; i++) assert(log.ids[i] == i, "FIFO order broken at %d", i);
        io::printfn("fifo: %d jobs in order", log.len);
    }

    // 2) Четыре рабочих, 500 задач через очередь на 16 мест.
    {
        ThreadPool pool;
        CollatzJob[500] jobs;
        pool.start(4);
        for (int i = 0; i < 500; i++)
        {
            jobs[i].start = (long)i + 1;
            pool.submit(&collatz_job, &jobs[i]);
        }
        int done = pool.stop();
        assert(done == 500, "expected 500 jobs, got %d", done);

        long total = 0;
        int best = 0;
        for (int i = 0; i < 500; i++)
        {
            assert(jobs[i].steps == collatz_steps((long)i + 1), "job %d wrong", i);
            total += jobs[i].steps;
            if (jobs[i].steps > jobs[best].steps) best = i;
        }
        io::printfn("pool: %d jobs executed", done);
        io::printfn("collatz: total steps %d, longest start %d (%d steps)", total, jobs[best].start, jobs[best].steps);
    }

    // 3) Пул без задач должен корректно остановиться.
    {
        ThreadPool pool;
        pool.start(3);
        assert(pool.stop() == 0);
        io::printn("empty pool: stopped cleanly");
    }
}
