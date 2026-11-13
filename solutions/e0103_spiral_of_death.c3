// =====================================================================
//  E0103 · Спираль смерти
// =====================================================================
//
//  Сначала прочитайте engine/docs/01_game_loop.md (раздел 4).
//
//  Если один тик update стоит дороже, чем DT реального времени, цикл
//  с аккумулятором попадает в «спираль смерти»: отстали → нужно больше
//  тиков → кадр длиннее → отстали ещё сильнее. То же происходит после
//  одного гигантского кадра (загрузка, брейкпойнт, свёрнутое окно).
//
//  Здесь нет настоящих часов: длительность кадра вычисляется по МОДЕЛИ
//  СТОИМОСТИ — кадр длится RENDER_COST + steps * UPDATE_COST, где steps —
//  число тиков в этом кадре. Так поведение воспроизводимо до микросекунды.
//
//  Наивный цикл (naive_advance) уже написан — запустите и посмотрите,
//  как растёт число тиков на кадр.
//
//  Защищённый цикл применяет две защиты:
//    1. длительность кадра обрезается до max_frame_us; обрезанное
//       время прибавляется к dropped_us, счётчик clamped_frames++;
//    2. за кадр выполняется не больше max_steps тиков; если после этого
//       в аккумуляторе осталось >= dt, лишние ЦЕЛЫЕ шаги отбрасываются
//       (acc оставляем как acc % dt), отброшенное идёт в dropped_us,
//       счётчик limited_frames++.
//
//  Главный инвариант: время не исчезает бесследно —
//      ticks * dt + acc + dropped == суммарное реальное время.
//  Отброшенное время — это замедление игры относительно реальности;
//  его надо считать, чтобы профайлер мог сказать «бюджет превышен».
//
//  ЗАДАЧА: реализуйте ProtectedLoop.advance.
//
import std::io;

struct ProtectedLoop
{
    long dt_us;
    long max_frame_us;
    int  max_steps;
    long acc_us;
    long ticks;
    long dropped_us;
    int  clamped_frames;
    int  limited_frames;
}

// Возвращает число выполненных тиков.
fn int ProtectedLoop.advance(&self, long frame_us)
{
    if (frame_us > self.max_frame_us)
    {
        self.dropped_us += frame_us - self.max_frame_us;
        frame_us = self.max_frame_us;
        self.clamped_frames++;
    }
    self.acc_us += frame_us;
    int steps = 0;
    while (self.acc_us >= self.dt_us && steps < self.max_steps)
    {
        self.acc_us -= self.dt_us;
        self.ticks++;
        steps++;
    }
    if (self.acc_us >= self.dt_us)
    {
        long keep = self.acc_us % self.dt_us;
        self.dropped_us += self.acc_us - keep;
        self.acc_us = keep;
        self.limited_frames++;
    }
    return steps;
}

// Наивная версия — без защит.
fn int naive_advance(long* acc, long dt, long frame_us)
{
    *acc += frame_us;
    int steps = 0;
    while (*acc >= dt) { *acc -= dt; steps++; }
    return steps;
}

const long DT = 10_000;
const long RENDER_COST = 2_000;

fn void main()
{
    // --- 1. Наивный цикл при UPDATE_COST > DT ---
    long update_cost = 12_000;
    long acc = 0;
    long frame = DT;
    io::printf("naive steps:");
    int last_steps = 0;
    for (int i = 0; i < 14; i++)
    {
        int steps = naive_advance(&acc, DT, frame);
        io::printf(" %d", steps);
        frame = RENDER_COST + steps * update_cost;   // столько длился этот кадр
        last_steps = steps;
    }
    io::printn();
    assert(last_steps >= 5, "the naive loop should be spiralling");

    // --- 2. Защищённый цикл при той же стоимости ---
    ProtectedLoop p = { .dt_us = DT, .max_frame_us = 50_000, .max_steps = 3 };
    long real = 0;
    long worst_frame = 0;
    frame = DT;
    for (int i = 0; i < 200; i++)
    {
        int steps = p.advance(frame);
        real += frame;
        assert(steps <= p.max_steps, "too many steps: %d", steps);
        assert(p.acc_us >= 0 && p.acc_us < DT, "acc out of range: %d", p.acc_us);
        assert(p.ticks * DT + p.acc_us + p.dropped_us == real, "time leaked at frame %d", i);
        frame = RENDER_COST + steps * update_cost;
        if (frame > worst_frame) worst_frame = frame;
    }
    assert(worst_frame <= RENDER_COST + p.max_steps * update_cost);
    io::printfn("protected: ticks=%d dropped=%dus limited=%d clamped=%d worst_frame=%dus",
                p.ticks, p.dropped_us, p.limited_frames, p.clamped_frames, worst_frame);
    io::printfn("game time runs at %d%% of real time", p.ticks * DT * 100 / real);

    // --- 3. Брейкпойнт: один кадр длиной 5 секунд, обновление дешёвое ---
    ProtectedLoop q = { .dt_us = DT, .max_frame_us = 100_000, .max_steps = 8 };
    long[] frames = { 16_000, 16_000, 5_000_000, 16_000, 16_000 };
    real = 0;
    io::printf("breakpoint steps:");
    foreach (f : frames)
    {
        int steps = q.advance(f);
        real += f;
        assert(q.ticks * DT + q.acc_us + q.dropped_us == real, "time leaked");
        io::printf(" %d", steps);
    }
    io::printn();
    assert(q.clamped_frames == 1 && q.limited_frames == 1);
    io::printfn("breakpoint: ticks=%d dropped=%dus", q.ticks, q.dropped_us);
    io::printn("spiral of death avoided");
}
