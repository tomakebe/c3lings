// =====================================================================
//  E0101 · Фиксированный шаг и аккумулятор
// =====================================================================
//
//  Сначала прочитайте engine/docs/01_game_loop.md (разделы 1–2).
//
//  Симуляция идёт шагами одной длины DT, а реальное время кадров
//  складывается в аккумулятор и «выплачивается» целыми шагами:
//
//      acc += frame_time;
//      while (acc >= DT) { update(DT); acc -= DT; }
//
//  Время мы храним в ЦЕЛЫХ микросекундах (`long`), а не в double
//  секундах: так сумма кадров точна, и число тиков не «плавает» от
//  ошибок округления (см. раздел 2.4 главы).
//
//  Чтобы тест был детерминированным, настоящих часов здесь нет:
//  длительности кадров заданы массивом — это «фальшивые часы».
//
//  Инварианты правильного аккумулятора (их проверяет main):
//    * после advance() всегда 0 <= acc < DT;
//    * за всё время выполнено ровно total_time / DT тиков (целочисленно),
//      а acc == total_time % DT — время не теряется и не создаётся;
//    * в одном кадре может быть 0, 1 или несколько тиков.
//
//  ЗАДАЧА: реализуйте FixedStepper.advance: добавить длительность кадра
//  в аккумулятор, выполнить столько шагов, сколько помещается
//  (для каждого шага увеличить self.ticks и вызвать self.on_tick),
//  вернуть число шагов, выполненных в этом кадре.
//
import std::io;

alias TickFn = fn void(long tick);

struct FixedStepper
{
    long dt_us;      // длина шага симуляции
    long acc_us;     // непросимулированный остаток реального времени
    long ticks;      // сколько шагов выполнено всего
    TickFn on_tick;  // "update" игры
}

fn int FixedStepper.advance(&self, long frame_us)
{
    self.acc_us += frame_us;
    int steps = 0;
    while (self.acc_us >= self.dt_us)
    {
        self.on_tick(self.ticks);
        self.ticks++;
        self.acc_us -= self.dt_us;
        steps++;
    }
    return steps;
}

long g_last_tick = -1;
int g_calls = 0;

fn void count_tick(long tick)
{
    // Тики должны идти строго подряд: 0, 1, 2, ...
    assert(tick == g_last_tick + 1, "tick %d after %d", tick, g_last_tick);
    g_last_tick = tick;
    g_calls++;
}

fn void run_schedule(String name, long dt_us, long[] frames)
{
    g_last_tick = -1;
    g_calls = 0;
    FixedStepper s = { .dt_us = dt_us, .on_tick = &count_tick };
    long total = 0;
    int[8] hist;   // сколько кадров имели 0,1,2,... тиков
    foreach (f : frames)
    {
        int steps = s.advance(f);
        total += f;
        assert(s.acc_us >= 0 && s.acc_us < dt_us, "accumulator out of range: %d", s.acc_us);
        assert(s.ticks == total / dt_us, "ticks %d, expected %d", s.ticks, total / dt_us);
        assert(s.acc_us == total % dt_us, "time lost or created");
        hist[steps < 7 ? steps : 7]++;
    }
    assert(g_calls == s.ticks, "on_tick must be called once per tick");
    io::printf("%-12s frames=%3d ticks=%3d acc=%5d  hist:", name, frames.len, s.ticks, s.acc_us);
    for (int i = 0; i < 7; i++) io::printf(" %d:%d", i, hist[i]);
    io::printn();
}

fn void main()
{
    const long DT = 16_667;   // ~60 Гц

    // Монитор 144 Гц: кадры по ~6944 мкс -> то 0, то 1 тик.
    long[100] fast;
    foreach (&f : fast) *f = 6_944;
    run_schedule("144Hz", DT, &fast);

    // 30 Гц: по 2 тика за кадр.
    long[50] slow;
    foreach (&f : slow) *f = 33_334;
    run_schedule("30Hz", DT, &slow);

    // Рваный ритм: подвисание на 100 мс и серия коротких кадров.
    long[] jitter = { 16_000, 17_500, 100_000, 1_000, 1_000, 1_000, 16_667, 33_000, 5_000, 12_000 };
    run_schedule("jitter", DT, jitter);

    // Ровно попадаем в шаг: каждый кадр = 1 тик, acc всегда 0.
    long[60] exact;
    foreach (&f : exact) *f = DT;
    run_schedule("exact", DT, &exact);

    io::printn("fixed step OK");
}
