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
    // TODO: обрезать frame_time по max_frame (учесть clipped), накопить,
    // посчитать шаги, обновить ticks
    (void)frame_time;
    return 1;
}

<* Доля следующего тика, 0..255 (для интерполяции рендера). *>
fn int FixedLoop.alpha256(&self) => (int)(self.accumulator * 256 / self.dt);
