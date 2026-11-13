// =====================================================================
//  099 · Каналы и пулы потоков
// =====================================================================
//
//  «Не общайтесь через общую память — делитесь памятью через общение»
//  (девиз Go). Вместо того чтобы вручную собирать очередь из мьютекса
//  и двух условных переменных (как в 097), можно взять готовый КАНАЛ.
//
//  Каналы (std::thread::channel)
//  -----------------------------
//  Это generic-модуль: тип элемента — параметр.
//
//      import std::thread::channel;
//      alias IntChan = BufferedChannel{int};
//
//      IntChan* ch = channel::create_buffered{int}(mem, 16)!!; // ёмкость 16
//      defer ch.destroy();
//
//      ch.push(42)!!;        // блокируется, если буфер полон
//      int? v = ch.pop();    // блокируется, если буфер пуст
//      ch.close();           // больше push'ей не будет
//
//  Виды каналов:
//    * create_buffered{T}(alloc, n) — буфер на n элементов: производитель
//      может «убежать вперёд» не больше чем на n;
//    * create_unbuffered{T}(alloc) — рандеву: push ждёт, пока кто-то
//      сделает pop (передача из рук в руки);
//    * create_unbounded{T}(alloc) — растущий буфер: push никогда не
//      блокируется (но память может кончиться, если читатель отстаёт).
//  Есть и неблокирующие try_push / try_pop.
//
//  Закрытие — это сигнал «конец данных». После close() pop() сначала
//  отдаёт оставшиеся элементы, а потом возвращает ошибку
//  thread::CHANNEL_CLOSED. Поэтому цикл потребителя пишется так:
//
//      while (true)
//      {
//          int? v = ch.pop();
//          if (catch v) break;     // канал закрыт и пуст
//          ...обработать v...
//      }
//
//  Забыли close() — потребители будут вечно ждать в pop(), join никогда
//  не вернётся: программа повиснет. Закрывает канал тот, кто в него
//  пишет (и только один раз), — тогда никто не напишет в закрытый канал.
//
//  Шаблон «worker pool на каналах»: N потоков читают задания из одного
//  канала. Каждое задание достанется ровно одному потоку — какому,
//  заранее неизвестно, поэтому результаты либо складываются в слоты по
//  индексу задания, либо суммируются в поля «своего» потока и
//  объединяются после join.
//
//  Пул потоков (std::thread, ThreadPool)
//  -------------------------------------
//  Создавать поток на каждую мелкую задачу дорого (десятки
//  микросекунд + стек). Пул держит несколько рабочих потоков и
//  очередь задач:
//
//      ThreadPool pool;
//      pool.init(mem, 4)!!;                 // не больше 4 потоков
//      pool.add_task(&my_task, &args)!!;    // alias ThreadPoolTaskFn = fn void(void* arg)
//      pool.destroy();                      // дождаться ВСЕХ задач и остановить потоки
//
//  Аргумент — сырой void*: пул не копирует ваши данные. Объект, на
//  который он указывает, должен жить, пока задача не выполнится (здесь
//  — до pool.destroy()). Передать адрес локальной переменной из тела
//  цикла — классическая ошибка (use-after-scope).
//
//  Для сравнения: в Go каналы встроены в язык, в Rust — std::sync::mpsc
//  и crossbeam, в C++ готовых каналов в стандарте нет до сих пор.
//
//  ЗАДАЧА:
//    1. В collatz_worker читайте задания из канала, пока он не закрыт.
//    2. В main закройте канал заданий, когда всё отправлено.
//    3. Отправьте задачи в пул (замените ???).
//
//  Ожидаемый вывод:
//      jobs: 10000, total steps: 849666, longest: 6171 (261 steps)
//      pool: sum of squares 0..99 = 328350
//
import std::io, std::thread, std::thread::channel;

alias JobChan = BufferedChannel{int};

fn int collatz_steps(int start)
{
    long n = start;
    int steps = 0;
    while (n != 1)
    {
        n = n % 2 == 0 ? n / 2 : 3 * n + 1;
        steps++;
    }
    return steps;
}

struct WorkerStats
{
    JobChan* jobs;
    int count;
    long total_steps;
    int best_n;
    int best_steps;
}

fn int collatz_worker(void* arg)
{
    WorkerStats* st = arg;
    // TODO: в цикле забирайте числа из st.jobs, пока канал не закрыт;
    //       для каждого числа n: st.count++, прибавьте collatz_steps(n)
    //       к st.total_steps и обновите best_n/best_steps (при равенстве
    //       шагов оставляйте меньшее n).
    while (true)
    {
        int? n = st.jobs.pop();
        if (catch n) break;
        int steps = collatz_steps(n);
        st.count++;
        st.total_steps += steps;
        if (steps > st.best_steps || (steps == st.best_steps && n < st.best_n))
        {
            st.best_n = n;
            st.best_steps = steps;
        }
    }
    return 0;
}

struct SquareTask
{
    int n;
    long result;
}

fn void square_task(void* arg)
{
    SquareTask* t = arg;
    t.result = (long)t.n * t.n;
}

fn void main()
{
    // ---- каналы: 4 рабочих потока читают из одного канала ----
    JobChan* jobs = channel::create_buffered{int}(mem, 64)!!;
    defer jobs.destroy();

    WorkerStats[4] stats;
    Thread[4] workers;
    foreach (i, &t : workers)
    {
        stats[i].jobs = jobs;
        t.create(&collatz_worker, &stats[i])!!;
    }
    for (int n = 1; n <= 10_000; n++) jobs.push(n)!!;
    // TODO: сообщите рабочим, что заданий больше не будет
    jobs.close();

    foreach (t : workers) t.join()!!;

    int count = 0;
    long total = 0;
    int best_n = 0;
    int best_steps = -1;
    foreach (st : stats)
    {
        count += st.count;
        total += st.total_steps;
        if (st.best_steps > best_steps || (st.best_steps == best_steps && st.best_n < best_n))
        {
            best_n = st.best_n;
            best_steps = st.best_steps;
        }
    }
    io::printfn("jobs: %d, total steps: %d, longest: %d (%d steps)", count, total, best_n, best_steps);

    // ---- пул потоков: результаты пишутся в слоты по индексу ----
    ThreadPool pool;
    pool.init(mem, 4)!!;
    SquareTask[100] tasks;
    foreach (i, &task : tasks)
    {
        task.n = (int)i;
        pool.add_task(&square_task, task)!!;
    }
    pool.destroy();   // ждёт выполнения всех задач

    long sum = 0;
    foreach (task : tasks) sum += task.result;
    io::printfn("pool: sum of squares 0..99 = %d", sum);
}
