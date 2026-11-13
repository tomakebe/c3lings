// =====================================================================
//  e1203 · parallel_for и детерминированная редукция
// =====================================================================
//
//  Сначала прочитайте engine/docs/12_multithreading.md (раздел
//  «parallel_for: гранулярность и редукции»).
//
//  Самая частая форма параллелизма в движке — «сделай одно и то же с
//  каждым из N элементов»: обновить 10 000 частиц, отсечь 5 000 объектов
//  по фрустуму, пересчитать матрицы скелетов. Это parallel_for.
//
//  Диапазон режется на куски (chunks) фиксированного размера. Потоки
//  забирают куски динамически через один атомарный счётчик:
//
//      next_chunk: 0 ──add(1)──► поток A берёт кусок 0
//                  1 ──add(1)──► поток B берёт кусок 1
//                  2 ──add(1)──► поток A (уже освободился) берёт кусок 2
//                  ...пока begin < count
//
//  Это даёт балансировку нагрузки бесплатно: быстрый поток просто
//  возьмёт больше кусков. Размер куска — компромисс: слишком мелкий —
//  тратим время на атомики и промахи кеша, слишком крупный — плохой
//  баланс в конце («хвост»).
//
//  Редукции (сумма, минимум, AABB) — отдельная тема. Сложение float НЕ
//  ассоциативно: (a + b) + c != a + (b + c) в общем случае. Если потоки
//  будут складывать в общую переменную «как придётся», результат будет
//  плавать от запуска к запуску — смерть для детерминированной симуляции,
//  реплеев и lockstep-сети. Правильный приём:
//
//      partial[chunk_index] = сумма куска     // каждый кусок пишет СВОЙ слот
//      ...join...
//      total = partial[0] + partial[1] + ...  // в фиксированном порядке
//
//  Тогда результат зависит только от размера куска, но не от числа
//  потоков и не от планировщика ОС.
//
//  ЗАДАЧА:
//    1. Реализуйте pf_worker: цикл захвата кусков через next_chunk.add(1).
//    2. Реализуйте parallel_sum через parallel_for с частичными суммами.
//  main проверит, что сумма побитово совпадает при 1, 2, 4 и 7 потоках.
//
import std::io, std::thread, std::atomic;

alias RangeFn = fn void(usz begin, usz end, usz chunk_index, void* ctx);

struct ParallelFor
{
    usz count;              // всего элементов
    usz chunk_size;         // элементов в куске
    RangeFn body;
    void* ctx;
    Atomic{usz} next_chunk; // следующий незанятый кусок
}

// Тело каждого потока. Возвращает, сколько кусков он обработал.
fn int pf_worker(void* arg)
{
    ParallelFor* pf = arg;
    int processed = 0;
    // TODO: в цикле:
    //   * захватить номер куска: pf.next_chunk.add(1) возвращает СТАРОЕ значение;
    //   * begin = chunk * chunk_size; если begin >= count — работы больше нет, выйти;
    //   * end = min(begin + chunk_size, count);
    //   * вызвать pf.body(begin, end, chunk, pf.ctx) и посчитать кусок в processed.
    return processed;
}

fn usz chunk_count(usz count, usz chunk_size) => (count + chunk_size - 1) / chunk_size;

const MAX_THREADS = 8;

// Запускает body на всех кусках, используя `threads` потоков (включая
// вызывающий). Возвращает общее число обработанных кусков.
fn int parallel_for(int threads, usz count, usz chunk_size, RangeFn body, void* ctx)
{
    assert(threads >= 1 && threads <= MAX_THREADS);
    ParallelFor pf = { .count = count, .chunk_size = chunk_size, .body = body, .ctx = ctx };
    Thread[MAX_THREADS] ts;
    for (int i = 1; i < threads; i++) ts[i].create(&pf_worker, &pf)!!;
    int total = pf_worker(&pf); // вызывающий поток тоже работает, а не просто ждёт
    for (int i = 1; i < threads; i++) total += ts[i].join()!!;
    return total;
}

// ------------------------------------------------ редукция

struct SumCtx
{
    float[] data;
    float[] partial; // по одному слоту на кусок
}

fn void sum_body(usz begin, usz end, usz chunk_index, void* ctx)
{
    SumCtx* s = ctx;
    float acc = 0;
    for (usz i = begin; i < end; i++) acc += s.data[i];
    s.partial[chunk_index] = acc;
}

// Детерминированная параллельная сумма.
fn float parallel_sum(int threads, float[] data, usz chunk_size)
{
    // TODO:
    //   * выделить массив partial на chunk_count(...) слотов (mem::new_array, не забыть free);
    //   * запустить parallel_for с sum_body и SumCtx;
    //   * сложить partial В ПОРЯДКЕ ИНДЕКСОВ и вернуть результат.
    return 0;
}

// Однопоточный эталон с той же разбивкой на куски.
fn float chunked_sum_reference(float[] data, usz chunk_size)
{
    float total = 0;
    for (usz begin = 0; begin < data.len; begin += chunk_size)
    {
        float acc = 0;
        for (usz i = begin; i < data.len && i < begin + chunk_size; i++) acc += data[i];
        total += acc;
    }
    return total;
}

// ------------------------------------------------ обычный parallel_for: интеграция частиц

struct Particles
{
    float[] x;
    float[] v;
    float dt;
}

fn void integrate_body(usz begin, usz end, usz chunk_index, void* ctx)
{
    Particles* p = ctx;
    for (usz i = begin; i < end; i++)
    {
        p.v[i] -= 9.75f * p.dt;
        p.x[i] += p.v[i] * p.dt;
    }
}

fn void main()
{
    const usz N = 100_000;
    float[] data = mem::new_array(float, N);
    defer free(data);
    foreach (i, &d : data) *d = 1.0f / (float)(i + 1);

    // 1) Сумма: побитово одинакова при любом числе потоков.
    float reference = chunked_sum_reference(data, 1000);
    int[4] thread_counts = { 1, 2, 4, 7 };
    foreach (t : thread_counts)
    {
        for (int rep = 0; rep < 5; rep++)
        {
            float s = parallel_sum(t, data, 1000);
            assert(bitcast(s, uint) == bitcast(reference, uint), "threads=%d: sum differs", t);
        }
    }
    io::printfn("harmonic sum (chunk 1000): %.5f, identical for 1/2/4/7 threads", reference);

    // Другой размер куска — другая (но тоже стабильная) сумма.
    float r2 = chunked_sum_reference(data, 37);
    assert(bitcast(parallel_sum(4, data, 37), uint) == bitcast(r2, uint));
    io::printfn("harmonic sum (chunk 37):   %.5f, stable", r2);

    // 2) Неровный хвост: 1001 элемент кусками по 100 = 11 кусков.
    float[] small = data[:1001];
    usz chunks = chunk_count(small.len, 100);
    SumCtx ctx = { small, mem::new_array(float, (sz)chunks) };
    defer free(ctx.partial);
    int processed = parallel_for(3, small.len, 100, &sum_body, &ctx);
    assert(processed == 11, "expected 11 chunks, got %d", processed);
    io::printfn("tail: %d elements -> %d chunks", small.len, processed);

    // 3) Интеграция 100 000 частиц.
    Particles p = { mem::new_array(float, N), mem::new_array(float, N), 0.5f };
    defer { free(p.x); free(p.v); }
    foreach (i, &v : p.v) *v = (float)(i % 10);
    for (int step = 0; step < 4; step++) parallel_for(4, N, 512, &integrate_body, &p);
    // v_i после 4 шагов: (i%10) - 4*0.5*9.75 = (i%10) - 19.5
    for (usz i = 0; i < N; i++) assert(p.v[i] == (float)(i % 10) - 19.5f, "particle %d", i);
    io::printfn("particles: x[0] = %.3f, x[9] = %.3f", p.x[0], p.x[9]);
}
