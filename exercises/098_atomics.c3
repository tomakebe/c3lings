// =====================================================================
//  098 · Атомики и compare_exchange
// =====================================================================
//
//  Мьютекс — надёжный, но тяжёлый инструмент: при конфликте поток
//  засыпает в ядре ОС. Для простых операций над одним словом памяти
//  процессор умеет кое-что лучше — АТОМАРНЫЕ инструкции (lock xadd,
//  lock cmpxchg на x86). Атомарная операция неделима: никакой другой
//  поток не увидит её «наполовину».
//
//  В C3 (модуль std::atomic) это обобщённый тип Atomic{Type}:
//
//      import std::atomic;
//      Atomic{long} hits;          // нулевое значение — уже валидный атомик
//      hits.add(1);                // атомарно +1, возвращает СТАРОЕ значение
//      long n = hits.load();       // атомарно прочитать
//      hits.store(0);              // атомарно записать
//      // а также sub, and, or, xor, max, min...
//
//  compare_exchange (CAS) — основа всех lock-free алгоритмов:
//
//      bool ok = a.compare_exchange(&expected, desired);
//
//  Атомарно: «если в a лежит expected — запиши desired и верни true;
//  иначе запиши текущее значение в expected и верни false». Типичный
//  CAS-цикл «прочитать — вычислить — попытаться записать»:
//
//      int cur = a.load();
//      while (!a.compare_exchange(&cur, f(cur))) {}   // cur обновится сам
//
//  Если между load и CAS кто-то поменял значение, CAS провалится, cur
//  получит свежее значение, и мы повторим. Так можно атомарно сделать
//  ЛЮБУЮ операцию над одним словом, даже ту, которой нет готовой.
//
//  Порядок памяти (memory ordering)
//  --------------------------------
//  Это самая коварная часть. Компилятор и процессор переставляют
//  обращения к памяти, если в одном потоке это незаметно. Для других
//  потоков — заметно. Каждая атомарная операция принимает порядок
//  (enum AtomicOrdering), последним аргументом:
//
//    SEQ_CONSISTENT (по умолчанию) — самый строгий: все потоки видят
//        все SEQ_CONSISTENT-операции в едином общем порядке. Если не
//        уверены — используйте его.
//    RELAXED — только атомарность, никаких гарантий порядка
//        относительно ДРУГИХ переменных. Идеален для счётчиков
//        статистики, когда результат читают после join.
//    RELEASE (для store) / ACQUIRE (для load) — пара для «публикации»:
//
//        // поток A                       // поток B
//        data = 42;                       while (!ready.load(ACQUIRE)) {}
//        ready.store(true, RELEASE);      io::printn(data);   // точно 42
//
//        Всё, что A записал ДО release-store, B видит ПОСЛЕ
//        acquire-load, прочитавшего это значение. С RELAXED здесь B
//        мог бы увидеть ready == true, но старый data. На x86 вы этого
//        почти никогда не заметите (сильная модель памяти), а на ARM —
//        легко. Именно поэтому такие баги «не воспроизводятся».
//    ACQUIRE_RELEASE — для read-modify-write операций, которым нужно и то
//        и другое.
//
//  У compare_exchange два порядка: при успехе и при неудаче.
//  Модель та же, что в C11/C++11 (std::memory_order_*) и в Zig
//  (.monotonic = RELAXED, .acquire, .release, .seq_cst).
//
//  Подводные камни:
//    * атомарна каждая операция по отдельности, но не их сочетание:
//      `if (a.load() < 10) a.add(1);` — гонка между проверкой и
//      добавлением. Нужен CAS-цикл;
//    * обычная переменная, к которой обращаются из разных потоков, — UB,
//      даже если «это просто bool-флаг». Используйте Atomic{bool};
//    * спинлок (крутиться на CAS) хорош только для очень коротких
//      критических секций. Под нагрузкой мьютекс почти всегда лучше.
//
//  ЗАДАЧА:
//    1. Реализуйте atomic_max через CAS-цикл.
//    2. Реализуйте SpinLock.lock (CAS false -> true, при успехе ACQUIRE)
//       и SpinLock.unlock (store false с RELEASE).
//
//  Ожидаемый вывод:
//      hits = 400000
//      max = 999978
//      guarded = 400000
//      message = 42
//
import std::io, std::thread, std::atomic;

const int THREADS = 4;
const int ITERS = 100_000;

fn void atomic_max(Atomic{int}* m, int value)
{
    // TODO: атомарно m = max(m, value) с помощью load + compare_exchange.
    //       Можно использовать RELAXED: результат читаем после join.
}

struct SpinLock
{
    Atomic{bool} locked;
}

fn void SpinLock.lock(&self)
{
    // TODO: в цикле пытайтесь заменить false на true.
    //       Не забудьте: при неудаче CAS записывает в expected текущее
    //       значение (true), а пытаться надо снова с false.
    //       Пока ждём, уступайте процессор: thread::yield();
}

fn void SpinLock.unlock(&self)
{
    // TODO
}

struct Shared
{
    Atomic{long} hits;
    Atomic{int} max;
    SpinLock spin;
    long guarded;      // обычная переменная, защищена spin
}

// Детерминированная «псевдослучайная» последовательность для потока id.
fn int sample(int id, int i) => (int)(((long)i * 7919 + (long)id * 104729) % 1_000_000);

Shared shared;

fn int worker_main(void* arg)
{
    int id = (int)(iptr)arg;
    for (int i = 0; i < ITERS; i++)
    {
        shared.hits.add(1, RELAXED);
        atomic_max(&shared.max, sample(id, i));
        shared.spin.lock();
        shared.guarded++;
        shared.spin.unlock();
    }
    return 0;
}

// Публикация через RELEASE/ACQUIRE.
int payload;
Atomic{bool} ready;

fn int producer(void* arg)
{
    payload = 42;                 // обычная запись...
    ready.store(true, RELEASE);   // ...публикуется release-записью
    return 0;
}

fn void main()
{
    Thread[THREADS] threads;
    foreach (i, &t : threads) t.create(&worker_main, (void*)(iptr)i)!!;
    foreach (t : threads) t.join()!!;

    int expected_max = 0;
    for (int id = 0; id < THREADS; id++)
    {
        for (int i = 0; i < ITERS; i++) expected_max = max(expected_max, sample(id, i));
    }
    assert(shared.max.load() == expected_max);

    io::printfn("hits = %d", shared.hits.load());
    io::printfn("max = %d", shared.max.load());
    io::printfn("guarded = %d", shared.guarded);

    Thread p;
    p.create(&producer, null)!!;
    while (!ready.load(ACQUIRE)) thread::yield();
    io::printfn("message = %d", payload);
    p.join()!!;
}
