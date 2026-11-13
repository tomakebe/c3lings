// =====================================================================
//  097 · Мьютексы и условные переменные
// =====================================================================
//
//  В прошлом упражнении потоки не делили записываемых данных. Но часто
//  общее состояние неизбежно: счётчик, очередь задач, кеш. Тогда к нему
//  нужно обращаться по очереди — под МЬЮТЕКСОМ (mutual exclusion).
//
//  Мьютекс
//  -------
//      Mutex mu;
//      mu.init()!!;          // обязательно до использования
//      defer mu.destroy();
//
//      mu.lock();
//      shared += 1;          // критическая секция: здесь в каждый момент
//      mu.unlock();          // может находиться только один поток
//
//  Пока один поток держит мьютекс, остальные, вызвавшие lock(),
//  засыпают и ждут. Помимо взаимного исключения, lock/unlock — это ещё
//  и барьеры памяти: всё, что поток записал перед unlock(), увидит
//  следующий поток, сделавший lock(). Без этого компилятор и процессор
//  вправе переставлять и кешировать обращения к памяти.
//
//  Забыть unlock (например, при раннем return) — значит повесить
//  программу навсегда. Поэтому в C3 пишут так:
//
//      mu.lock();
//      defer mu.unlock();    // выполнится при любом выходе из блока
//
//  или ещё короче — макросом с trailing-блоком:
//
//      mu.@in_lock()
//      {
//          shared += 1;
//      };
//
//  (Это аналог std::lock_guard в C++ и `defer mutex.unlock()` в Zig.
//  В Rust данные лежат ВНУТРИ Mutex<T>, и обратиться к ним без
//  блокировки нельзя по типам. В C3, как и в C, связь «этот мьютекс
//  защищает эти поля» — только ваша дисциплина. Держите их рядом в
//  одной структуре и пишите комментарий.)
//
//  Взаимная блокировка (deadlock): поток A держит mu1 и ждёт mu2, а
//  поток B держит mu2 и ждёт mu1. Лекарство — всегда брать мьютексы в
//  одном и том же порядке. Обычный Mutex не рекурсивный: повторный
//  lock() из того же потока — тоже deadlock (для этого есть
//  RecursiveMutex, но обычно это признак плохого дизайна).
//
//  Условная переменная
//  -------------------
//  Мьютекс отвечает на вопрос «кто сейчас работает с данными», но не
//  умеет «ждать, пока что-то случится» (очередь станет непустой).
//  Крутиться в цикле `while (empty) {}` — жечь процессор впустую. Для
//  ожидания есть ConditionVariable:
//
//      cond.wait(&mu);   // атомарно: отпустить mu и заснуть;
//                        // проснувшись — снова захватить mu
//      cond.signal();    // разбудить ОДИН ждущий поток
//      cond.broadcast(); // разбудить ВСЕ ждущие потоки
//
//  Золотое правило: wait вызывается ТОЛЬКО под мьютексом и ТОЛЬКО в
//  цикле while, который перепроверяет условие:
//
//      mu.lock();
//      while (count == 0) cond.wait(&mu);    // НЕ if!
//      ...берём элемент...
//      mu.unlock();
//
//  Почему while, а не if:
//    * ложные пробуждения (spurious wakeups): ОС вправе разбудить поток
//      без всякого signal — это разрешено POSIX;
//    * пока разбуженный поток снова захватывал мьютекс, другой поток
//      мог успеть забрать элемент первым.
//
//  И второе правило: меняете условие — делайте signal/broadcast (лучше
//  под тем же мьютексом). Иначе ждущий поток проспит вечно («потерянное
//  пробуждение»). Для «закрытия» очереди, когда должны проснуться все
//  потребители, нужен broadcast.
//
//  ЗАДАЧА:
//    1. Защитите счётчик в increment_worker мьютексом.
//    2. В Queue.pop допишите условие ожидания (ждать, пока очередь пуста
//       и не закрыта).
//    3. В Queue.push разбудите одного потребителя после добавления.
//
//  Ожидаемый вывод:
//      counter = 400000
//      consumed 10000 items, sum = 50005000
//
import std::io, std::thread;

// --------------------------------------------------------- часть 1

struct Counter
{
    Mutex mu;      // защищает value
    long value;
}

fn int increment_worker(void* arg)
{
    Counter* c = arg;
    for (int i = 0; i < 100_000; i++)
    {
        // TODO: эта операция должна выполняться под c.mu
        c.value++;
    }
    return 0;
}

// --------------------------------------------------------- часть 2

excuse QUEUE_CLOSED;

const int CAP = 8;

struct Queue
{
    Mutex mu;                       // защищает всё, что ниже
    ConditionVariable not_empty;    // «появился элемент или очередь закрыта»
    ConditionVariable not_full;     // «появилось место»
    int[CAP] buf;
    int head;
    int count;
    bool closed;
}

fn void Queue.init(&self)
{
    self.mu.init()!!;
    self.not_empty.init()!!;
    self.not_full.init()!!;
}

fn void Queue.destroy(&self)
{
    self.mu.destroy();
    self.not_empty.destroy();
    self.not_full.destroy();
}

fn void Queue.push(&self, int value)
{
    self.mu.@in_lock()
    {
        while (self.count == CAP) self.not_full.wait(&self.mu);
        self.buf[(self.head + self.count) % CAP] = value;
        self.count++;
        // TODO: разбудите одного потребителя
    };
}

fn int? Queue.pop(&self)
{
    self.mu.lock();
    defer self.mu.unlock();
    while (???) self.not_empty.wait(&self.mu);
    if (self.count == 0) return QUEUE_CLOSED~;   // закрыта и пуста
    int value = self.buf[self.head];
    self.head = (self.head + 1) % CAP;
    self.count--;
    self.not_full.signal();
    return value;
}

fn void Queue.close(&self)
{
    self.mu.@in_lock()
    {
        self.closed = true;
        self.not_empty.broadcast();   // будим ВСЕХ: каждый должен увидеть closed
    };
}

struct ConsumerStats
{
    Queue* queue;
    int items;
    long sum;
}

fn int consumer(void* arg)
{
    ConsumerStats* st = arg;
    while (true)
    {
        int? v = st.queue.pop();
        if (catch v) break;
        st.items++;
        st.sum += v;
    }
    return 0;
}

fn void main()
{
    // часть 1: 4 потока по 100000 инкрементов
    Counter counter;
    counter.mu.init()!!;
    defer counter.mu.destroy();
    Thread[4] workers;
    foreach (&t : workers) t.create(&increment_worker, &counter)!!;
    foreach (t : workers) t.join()!!;
    io::printfn("counter = %d", counter.value);

    // часть 2: один производитель (main) и три потребителя
    Queue queue;
    queue.init();
    defer queue.destroy();

    ConsumerStats[3] stats;
    Thread[3] consumers;
    foreach (i, &t : consumers)
    {
        stats[i].queue = &queue;
        t.create(&consumer, &stats[i])!!;
    }
    for (int i = 1; i <= 10_000; i++) queue.push(i);
    queue.close();
    foreach (t : consumers) t.join()!!;

    // Как элементы распределились между потребителями — дело случая,
    // поэтому печатаем только суммы.
    int items = 0;
    long sum = 0;
    foreach (st : stats)
    {
        items += st.items;
        sum += st.sum;
    }
    io::printfn("consumed %d items, sum = %d", items, sum);
}
