// =====================================================================
//  e1101 · Интеграторы: Эйлер, полунеявный Эйлер, Верле, RK4
// =====================================================================
//
//  Сначала прочитайте engine/docs/11_physics.md (раздел «Интеграторы»).
//
//  Физический движок каждый шаг решает одну и ту же задачу: зная
//  положение x, скорость v и ускорение a(x), найти x и v через dt.
//  Точного решения у нас нет, поэтому мы ИНТЕГРИРУЕМ численно — и
//  от выбора схемы зависит, взорвётся ли симуляция.
//
//  Испытательный стенд — пружина (гармонический осциллятор):
//      a(x) = -k/m * x,   k = m = 1,   x0 = 1, v0 = 0
//  Точное решение x(t) = cos(t), а энергия E = v²/2 + x²/2 = 0.5
//  должна сохраняться ВСЕГДА. По тому, как схема обращается с
//  энергией, сразу видно её характер:
//
//  1) Явный Эйлер (explicit Euler) — обе величины по СТАРЫМ значениям:
//         x' = x + v * dt
//         v' = v + a(x) * dt
//     Энергия растёт каждый шаг в (1 + dt²) раз — пружина «раскачивается»
//     и в итоге симуляция взрывается. В движках не используют.
//
//  2) Полунеявный (симплектический) Эйлер — сначала скорость, потом
//     положение по НОВОЙ скорости:
//         v' = v + a(x) * dt
//         x' = x + v' * dt
//     Та же цена, но энергия не убегает, а колеблется около верного
//     значения. Именно это стоит в Box2D, Bullet и большинстве игр.
//
//  3) Velocity Verlet — второй порядок точности, одно вычисление
//     ускорения на шаг (если кешировать a):
//         x' = x + v*dt + a(x)*dt²/2
//         v' = v + (a(x) + a(x'))/2 * dt
//
//  4) RK4 (Рунге — Кутта 4-го порядка) — четыре оценки производной:
//         k1 = f(s),  k2 = f(s + k1*dt/2),  k3 = f(s + k2*dt/2),
//         k4 = f(s + k3*dt),  s' = s + (k1 + 2k2 + 2k3 + k4) * dt/6
//     где s = (x, v), f(s) = (v, a(x)). Очень точен, но в 4 раза
//     дороже и плохо дружит с контактами/ограничениями (каждая
//     подоценка «видит» мир, в котором ещё не разрешены коллизии).
//     Хорош для орбит, пружин подвески, камеры — гладких сил.
//
//  ЗАДАЧА: реализуйте четыре функции шага (TODO). main() проверит
//  каждую схему против точного решения и закона сохранения энергии
//  и напечатает таблицу.
//
import std::io, std::math;

const double K = 1.0;
const double DT = 0.1;
const int STEPS = 100;           // t = 10 секунд

struct State
{
    double x;
    double v;
}

fn double accel(double x) => -K * x;
fn double energy(State s) => 0.5 * s.v * s.v + 0.5 * K * s.x * s.x;

fn State step_explicit_euler(State s, double dt)
{
    return { s.x + s.v * dt, s.v + accel(s.x) * dt };
}

fn State step_semi_implicit_euler(State s, double dt)
{
    double v = s.v + accel(s.x) * dt;
    return { s.x + v * dt, v };
}

fn State step_velocity_verlet(State s, double dt)
{
    double a = accel(s.x);
    double x = s.x + s.v * dt + 0.5 * a * dt * dt;
    double v = s.v + 0.5 * (a + accel(x)) * dt;
    return { x, v };
}

fn State step_rk4(State s, double dt)
{
    double k1x = s.v;
    double k1v = accel(s.x);
    double k2x = s.v + k1v * dt / 2;
    double k2v = accel(s.x + k1x * dt / 2);
    double k3x = s.v + k2v * dt / 2;
    double k3v = accel(s.x + k2x * dt / 2);
    double k4x = s.v + k3v * dt;
    double k4v = accel(s.x + k3x * dt);
    return { s.x + (k1x + 2 * k2x + 2 * k3x + k4x) * dt / 6,
             s.v + (k1v + 2 * k2v + 2 * k3v + k4v) * dt / 6 };
}

alias StepFn = fn State(State, double);

fn State run(StepFn step, double* max_drift)
{
    State s = { 1.0, 0.0 };
    double e0 = energy(s);
    *max_drift = 0;
    for (int i = 0; i < STEPS; i++)
    {
        s = step(s, DT);
        double d = math::abs(energy(s) - e0);
        if (d > *max_drift) *max_drift = d;
    }
    return s;
}

fn void main()
{
    double t = DT * STEPS;
    double exact = math::cos(t);
    String[4] names = { "explicit euler", "semi-implicit euler", "velocity verlet", "rk4" };
    StepFn[4] fns = { &step_explicit_euler, &step_semi_implicit_euler, &step_velocity_verlet, &step_rk4 };
    State[4] res;
    double[4] drift;
    for (int i = 0; i < 4; i++)
    {
        res[i] = run(fns[i], &drift[i]);
        io::printfn("%-20s x=%8.5f  err=%.5f  energy=%.5f  max_drift=%.5f",
                    names[i], res[i].x, math::abs(res[i].x - exact), energy(res[i]), drift[i]);
    }

    // Явный Эйлер: энергия умножается на (1 + dt²) каждый шаг.
    assert(math::abs(energy(res[0]) - 0.5 * math::pow(1.0 + DT * DT, (double)STEPS)) < 1e-9, "explicit euler is wrong");
    // Полунеявный Эйлер: энергия ограничена (колеблется в пределах ~dt/2).
    assert(drift[1] > 0 && drift[1] < 0.03, "semi-implicit euler is wrong");
    // Верле: второй порядок — заметно точнее.
    assert(math::abs(res[2].x - exact) < 0.01 && drift[2] < 0.002, "velocity verlet is wrong");
    // RK4: почти точное решение.
    assert(math::abs(res[3].x - exact) < 1e-5, "rk4 is wrong");
    io::printfn("exact x(10) = %.5f", exact);
}
