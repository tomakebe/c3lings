// =====================================================================
//  E0102 · Интерполяция состояния для рендера
// =====================================================================
//
//  Сначала прочитайте engine/docs/01_game_loop.md (раздел 3).
//
//  После цикла `while (acc >= DT)` в аккумуляторе остаётся хвост
//  0 <= acc < DT: реальное время, которое ещё не просимулировано.
//  Если рисовать просто последнее состояние, то при мониторе 144 Гц и
//  симуляции 100 Гц объект будет то стоять, то прыгать — дрожание.
//
//  Решение: хранить ДВА состояния — предыдущее и текущее — и рисовать
//
//      alpha  = acc / DT                    (0 <= alpha < 1)
//      render = prev + (curr - prev) * alpha
//
//  Цена — задержка на один тик: картинка отстаёт от симуляции на
//  (1 - alpha) * DT. Зато движение равномерное.
//
//  Важная тонкость — ТЕЛЕПОРТ. Если объект мгновенно перенесли, а prev
//  оставили старым, то в следующих кадрах интерполяция «протащит» его
//  через всю карту. Телепорт обязан сбросить prev = curr.
//
//  Здесь объект летит со скоростью 100 ед/с, шаг 10 мс, значит ровно
//  1 единица за тик. Поэтому правильно интерполированная позиция в
//  момент времени T равна (T / DT) - 1 (отставание на один тик), и
//  между соседними кадрами 144 Гц объект сдвигается на 0.6944 ед.
//
//  ЗАДАЧА: реализуйте
//    * Body.step     — запомнить prev и сдвинуть x на vel * dt;
//    * Body.teleport — перенести объект без «протаскивания»;
//    * Body.render_x — интерполированная позиция для данного alpha;
//    * compute_alpha — alpha из аккумулятора и шага (в double!).
//
import std::io, std::math;

struct Body
{
    double prev_x;
    double x;
    double vel;     // единиц в секунду
}

fn void Body.step(&self, long dt_us)
{
    // TODO: сохраните предыдущее состояние и проинтегрируйте позицию
    self.x += self.vel * (double)dt_us / 1_000_000.0;
}

fn void Body.teleport(&self, double to)
{
    // TODO: телепорт не должен «протаскивать» объект через интерполяцию
    self.x = to;
}

fn double Body.render_x(&self, double alpha)
{
    // TODO: интерполяция между prev_x и x
    return self.x;
}

fn double compute_alpha(long acc_us, long dt_us)
{
    // TODO: доля непросимулированного шага, 0 <= alpha < 1
    return 0;
}

const long DT = 10_000;      // 100 Гц
const long FRAME = 6_944;    // ~144 Гц

fn void main()
{
    Body b = { .vel = 100.0 };
    long acc = 0;
    long now = 0;
    long ticks = 0;
    double last_render = 0;
    bool have_last = false;
    double min_delta = 1e9;
    double max_delta = -1e9;

    for (int frame = 0; frame < 200; frame++)
    {
        now += FRAME;
        acc += FRAME;
        while (acc >= DT)
        {
            b.step(DT);
            acc -= DT;
            ticks++;
        }
        double alpha = compute_alpha(acc, DT);
        assert(alpha >= 0.0 && alpha < 1.0, "alpha out of [0,1): %f", alpha);
        if (ticks < 1) continue;

        double r = b.render_x(alpha);
        double expected = (double)now / (double)DT - 1.0;
        assert(math::abs(r - expected) < 1e-6, "frame %d: render %.4f, expected %.4f", frame, r, expected);
        if (have_last)
        {
            double d = r - last_render;
            if (d < min_delta) min_delta = d;
            if (d > max_delta) max_delta = d;
        }
        if (frame % 40 == 0) io::printfn("frame %3d ticks %3d alpha %.4f render_x %.4f", frame, ticks, alpha, r);
        last_render = r;
        have_last = true;
    }
    // Без интерполяции шаги были бы то 0, то 1; с ней — всегда 0.6944.
    assert(max_delta - min_delta < 1e-6, "motion is not smooth: deltas in [%.4f, %.4f]", min_delta, max_delta);
    io::printfn("smooth: every frame moves %.4f units", min_delta);

    // Телепорт: ни один кадр не должен показать точку между старым и новым местом.
    b.teleport(1000.0);
    for (int frame = 0; frame < 10; frame++)
    {
        acc += FRAME;
        while (acc >= DT) { b.step(DT); acc -= DT; ticks++; }
        double r = b.render_x(compute_alpha(acc, DT));
        assert(r >= 1000.0, "teleport smeared the object: render_x %.4f", r);
    }
    io::printfn("teleport: no smearing, x=%.4f", b.x);
    io::printn("interpolation OK");
}
