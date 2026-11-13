// ---------------------------------------------------------------------
//  mini::loop — фиксированный шаг симуляции с аккумулятором (глава 01).
//
//      реальное время кадра --> accumulator += frame_time
//      while (accumulator >= dt) { simulate(dt); accumulator -= dt; }
//      alpha = accumulator / dt   -> интерполяция при рендере
//
//  Время — в микросекундах (целые), чтобы не копить ошибку float.
//  Защита от «спирали смерти»: кадр длиннее max_frame обрезается —
//  после подвисания игра немного «замедлится», а не попытается
//  наверстать сотни тиков.
// ---------------------------------------------------------------------
module mini::loop;

struct FixedLoop
{
    long dt;
    long max_frame;
    long accumulator;
    long clipped;      // сколько микросекунд выброшено из-за max_frame
    int ticks;         // всего тиков симуляции
}

<* Учесть кадр длиной frame_time; вернуть число тиков, которые надо выполнить. *>
fn int FixedLoop.advance(&self, long frame_time)
{
    if (frame_time > self.max_frame)
    {
        self.clipped += frame_time - self.max_frame;
        frame_time = self.max_frame;
    }
    self.accumulator += frame_time;
    int steps = 0;
    while (self.accumulator >= self.dt)
    {
        self.accumulator -= self.dt;
        steps++;
    }
    self.ticks += steps;
    return steps;
}

<* Доля следующего тика, 0..255 (для интерполяции рендера). *>
fn int FixedLoop.alpha256(&self) => (int)(self.accumulator * 256 / self.dt);
