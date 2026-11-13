// =====================================================================
//  e1206 · Конвейер кадров: симуляция N параллельно с рендером N-1
// =====================================================================
//
//  Сначала прочитайте engine/docs/12_multithreading.md (раздел
//  «Конвейер кадров»).
//
//  Итог главы. Есть система задач со счётчиками (e1202, уже готова),
//  есть приём «куски + частичные результаты» (e1203). Осталось собрать
//  кадр так, как это делают Destiny, Uncharted 4 и многие другие:
//  пока симуляция считает кадр N, подготовка рендера (отсечение,
//  построение списка отрисовки) работает с результатами кадра N-1.
//
//      время ─────────────────────────────────────────────►
//      sim:     [ sim 0 ][ sim 1 ][ sim 2 ][ sim 3 ]
//      render:           [ rnd 0 ][ rnd 1 ][ rnd 2 ][ rnd 3 ]
//
//  Чтобы стадии не мешали друг другу, состояние мира ДВОЙНОЕ:
//
//      states[f % 2]       — сюда пишет sim(f)
//      states[(f + 1) % 2] — отсюда sim(f) читает кадр f-1,
//                            и ОТТУДА ЖЕ читает render(f-1)
//
//  Оба только читают общий буфер, а пишет каждый в своё — гонок нет,
//  мьютексы не нужны. Цена — задержка (latency) в один кадр между
//  симуляцией и картинкой; именно так и устроены реальные движки.
//
//  Каждый буфер помнит, какой кадр в нём лежит (поле `frame`).
//  kick_sim и kick_render проверяют штампы — если перепутать буферы,
//  программа упадёт на assert, а не тихо посчитает мусор.
//
//  ЗАДАЧА: реализуйте run_pipelined (TODO). Для каждого кадра f:
//    * один счётчик на кадр;
//    * запустить sim(f): kick_sim(f, src, dst, &c);
//    * если f > 0 — запустить render(f-1) из буфера кадра f-1;
//    * дождаться счётчика и свести результат рендера: finish_render(f-1).
//  После цикла остаётся отрендерить последний кадр. Результат обязан
//  совпасть с последовательной версией run_sequential.
//
import std::io, std::thread, std::atomic;

// ================================================================ система задач (из e1202, готова)

alias JobFn = fn void(void* data);

struct Counter { Atomic{int} value; }

struct Job
{
    JobFn func;
    void* data;
    Counter* counter;
}

const usz QUEUE_CAP = 256;

struct JobSystem
{
    Mutex mtx;
    ConditionVariable has_work;
    Job[QUEUE_CAP] ring;
    usz head, tail;
    bool quitting;
    Thread[8] threads;
    int worker_count;
}

fn void JobSystem.push(&self, Job job)
{
    self.mtx.lock();
    assert(self.tail - self.head < QUEUE_CAP, "job queue overflow");
    self.ring[self.tail % QUEUE_CAP] = job;
    self.tail++;
    self.has_work.signal();
    self.mtx.unlock();
}

fn bool JobSystem.try_pop(&self, Job* out)
{
    self.mtx.lock();
    defer self.mtx.unlock();
    if (self.head == self.tail) return false;
    *out = self.ring[self.head++ % QUEUE_CAP];
    return true;
}

fn bool JobSystem.wait_pop(&self, Job* out)
{
    self.mtx.lock();
    defer self.mtx.unlock();
    while (self.head == self.tail && !self.quitting) self.has_work.wait(&self.mtx);
    if (self.head == self.tail) return false;
    *out = self.ring[self.head++ % QUEUE_CAP];
    return true;
}

fn void execute_job(Job job)
{
    job.func(job.data);
    if (job.counter) job.counter.value.sub(1);
}

fn void JobSystem.run_jobs(&self, Job[] jobs, Counter* counter)
{
    counter.value.add((int)jobs.len);
    foreach (job : jobs)
    {
        job.counter = counter;
        self.push(job);
    }
}

fn void JobSystem.wait_for_counter(&self, Counter* counter)
{
    while (counter.value.load() != 0)
    {
        Job job;
        if (self.try_pop(&job)) { execute_job(job); } else { thread::yield(); }
    }
}

fn int worker_main(void* arg)
{
    JobSystem* js = arg;
    Job job;
    while (js.wait_pop(&job)) execute_job(job);
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

// ================================================================ мир

const ENTITIES = 2048;
const CHUNK = 256;
const CHUNKS = ENTITIES / CHUNK;
const FRAMES = 120;
const float DT = 1.0f / 30.0f;

struct WorldState
{
    int frame;                   // какой кадр лежит в буфере
    float[ENTITIES] x, y, vx, vy;
}

struct FrameResult
{
    int visible;
    long checksum;
}

struct Game
{
    JobSystem* js;
    WorldState[2] states;
    FrameResult[CHUNKS] render_partial; // частичные результаты рендера по кускам
    FrameResult[FRAMES] results;        // итог по каждому кадру
    // параметры текущих задач (по одной записи на кусок)
    SimChunk[CHUNKS] sim_jobs;
    RenderChunk[CHUNKS] render_jobs;
}

struct SimChunk
{
    WorldState* src;
    WorldState* dst;
    int begin, end;
}

struct RenderChunk
{
    Game* game;
    WorldState* src;
    int chunk;
}

fn void init_world(Game* g)
{
    WorldState* s = &g.states[1]; // «кадр -1»
    s.frame = -1;
    for (int i = 0; i < ENTITIES; i++)
    {
        s.x[i] = (float)(i % 100);
        s.y[i] = (float)(10 + (i * 37) % 90);
        s.vx[i] = (float)((i % 7) - 3);
        s.vy[i] = 0;
    }
}

fn void sim_chunk_job(void* data)
{
    SimChunk* j = data;
    for (int i = j.begin; i < j.end; i++)
    {
        float vy = j.src.vy[i] - 9.8f * DT;
        float y = j.src.y[i] + vy * DT;
        if (y < 0) { y = -y; vy = -vy * 0.75f; }
        float x = j.src.x[i] + j.src.vx[i] * DT;
        if (x >= 100) x -= 100;
        if (x < 0) x += 100;
        j.dst.x[i] = x;
        j.dst.y[i] = y;
        j.dst.vx[i] = j.src.vx[i];
        j.dst.vy[i] = vy;
    }
}

fn void render_chunk_job(void* data)
{
    RenderChunk* j = data;
    FrameResult r;
    for (int i = j.chunk * CHUNK; i < (j.chunk + 1) * CHUNK; i++)
    {
        if (j.src.y[i] < 50)
        {
            r.visible++;
            r.checksum += (long)(j.src.x[i] * 16) + (long)(j.src.y[i] * 16) * 7;
        }
    }
    j.game.render_partial[j.chunk] = r;
}

// Запустить симуляцию кадра `frame`: читать states[src], писать в states[dst].
fn void kick_sim(Game* g, int frame, int src, int dst, Counter* c)
{
    assert(src != dst);
    assert(g.states[src].frame == frame - 1, "sim(%d) must read the state of frame %d", frame, frame - 1);
    g.states[dst].frame = frame;
    Job[CHUNKS] jobs;
    for (int k = 0; k < CHUNKS; k++)
    {
        g.sim_jobs[k] = { &g.states[src], &g.states[dst], k * CHUNK, (k + 1) * CHUNK };
        jobs[k] = { &sim_chunk_job, &g.sim_jobs[k], null };
    }
    g.js.run_jobs(&jobs, c);
}

// Запустить подготовку рендера кадра `frame` из states[buf].
fn void kick_render(Game* g, int frame, int buf, Counter* c)
{
    assert(g.states[buf].frame == frame, "render(%d) reads a buffer holding frame %d", frame, g.states[buf].frame);
    Job[CHUNKS] jobs;
    for (int k = 0; k < CHUNKS; k++)
    {
        g.render_jobs[k] = { g, &g.states[buf], k };
        jobs[k] = { &render_chunk_job, &g.render_jobs[k], null };
    }
    g.js.run_jobs(&jobs, c);
}

// Свести частичные результаты рендера (после ожидания!) в фиксированном порядке.
fn void finish_render(Game* g, int frame)
{
    FrameResult r;
    foreach (p : g.render_partial)
    {
        r.visible += p.visible;
        r.checksum += p.checksum;
    }
    g.results[frame] = r;
}

// Эталон: всё по очереди, без перекрытия стадий.
fn void run_sequential(Game* g)
{
    for (int f = 0; f < FRAMES; f++)
    {
        Counter c;
        kick_sim(g, f, (f + 1) % 2, f % 2, &c);
        g.js.wait_for_counter(&c);
        kick_render(g, f, f % 2, &c);
        g.js.wait_for_counter(&c);
        finish_render(g, f);
    }
}

// Конвейер: sim(f) параллельно с render(f-1).
fn void run_pipelined(Game* g)
{
    for (int f = 0; f < FRAMES; f++)
    {
        Counter c;
        kick_sim(g, f, (f + 1) % 2, f % 2, &c);
        if (f > 0) kick_render(g, f - 1, (f + 1) % 2, &c);
        g.js.wait_for_counter(&c);
        if (f > 0) finish_render(g, f - 1);
    }
    Counter c;
    kick_render(g, FRAMES - 1, (FRAMES - 1) % 2, &c);
    g.js.wait_for_counter(&c);
    finish_render(g, FRAMES - 1);
}

JobSystem jobs;
Game seq_game;
Game pipe_game;

fn void main()
{
    jobs.start(3);

    seq_game.js = &jobs;
    init_world(&seq_game);
    run_sequential(&seq_game);

    for (int rep = 0; rep < 10; rep++)
    {
        pipe_game = {};
        pipe_game.js = &jobs;
        init_world(&pipe_game);
        run_pipelined(&pipe_game);
        for (int f = 0; f < FRAMES; f++)
        {
            assert(pipe_game.results[f].visible == seq_game.results[f].visible
                && pipe_game.results[f].checksum == seq_game.results[f].checksum,
                "frame %d differs from the sequential reference", f);
        }
    }
    jobs.stop();

    int[4] shown = { 0, 1, 60, FRAMES - 1 };
    foreach (f : shown)
    {
        io::printfn("frame %3d: visible %4d, checksum %d", f, seq_game.results[f].visible, seq_game.results[f].checksum);
    }
    io::printfn("pipelined == sequential for all %d frames (10 runs)", FRAMES);
}
