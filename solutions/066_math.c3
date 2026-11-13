// =====================================================================
//  066 · std::math
// =====================================================================
//
//  Модуль `std::math` — это <math.h> из C плюс много удобств.
//  Подключается `import std::math;`, вызывается с префиксом `math::`.
//
//  Константы:  math::PI, math::TAU (= 2π), math::E, math::SQRT2,
//              math::DOUBLE_EPSILON, math::FLOAT_MAX ...
//  Типы-пределы — свойства типов: int::max, int::min, double::max.
//
//  Почти всё здесь — МАКРОСЫ, которые подстраиваются под тип аргумента
//  (а не пачка sqrtf/sqrt/sqrtl, как в C):
//      math::sqrt(x), math::pow(x, y), math::exp, math::ln, math::log10,
//      math::log(x, base), math::sin/cos/tan, math::atan2(y, x),
//      math::floor, math::ceil, math::round (половинки — от нуля),
//      math::trunc, math::hypot(x, y)
//  float на входе -> float на выходе, double -> double. Целое
//  аргументом превращается в double: `math::sqrt(2)` — это 1.414...
//
//  Целочисленные и общие помощники:
//      math::abs(x), math::sign(x) (только для целых),
//      math::min(a, b, ...), math::max(a, b, ...)   — сколько угодно аргументов
//      math::clamp(x, lo, hi)                      — зажать в диапазон
//      math::gcd(a, b), math::lcm(a, b)
//      math::is_power_of_2(x), math::next_power_of_2(x)
//      math::deg_to_rad(d), math::rad_to_deg(r)
//      math::is_approx(a, b, eps)                  — сравнение с допуском
//
//  Три классические ловушки, одинаковые во всех языках:
//
//  1. Тригонометрия работает в РАДИАНАХ. `math::sin(30.0)` — это синус
//     30 радиан (≈ -0.988), а не 0.5. Переводите: math::deg_to_rad(30.0).
//
//  2. Числа с плавающей точкой неточны: 0.1 + 0.2 != 0.3 (это
//     0.30000000000000004). Сравнивайте с допуском:
//         math::is_approx(a, b, 1e-9)
//
//  3. Целочисленное деление отбрасывает дробную часть: 7 / 2 == 3.
//     В C `double avg = sum / n;` молча даёт 2.0 вместо 2.5. C3 такое
//     присваивание просто не компилирует («requires an explicit cast»),
//     потому что неясно, что вы имели в виду. Нужна дробь — приведите
//     операнд ДО деления: (double)sum / n.
//
//  ЗАДАЧА: исправьте три ошибки в вычислениях. Ожидаемый вывод:
//      sin(30 deg) = 0.500
//      hypot(3, 4) = 5.0
//      average = 2.50
//      0.1 + 0.2 ~= 0.3: true
//      clamp(150) = 100, clamp(-5) = 0
//      gcd = 6, lcm = 36, next pow2 = 128
//
import std::io;
import std::math;

fn void main()
{
    double s = math::sin(math::deg_to_rad(30.0));
    io::printfn("sin(30 deg) = %.3f", s);
    io::printfn("hypot(3, 4) = %.1f", math::hypot(3.0, 4.0));

    int[] values = { 1, 2, 3, 4 };
    int sum;
    foreach (v : values) sum += v;
    double average = (double)sum / values.len;
    io::printfn("average = %.2f", average);

    double x = 0.1 + 0.2;
    bool close = math::is_approx(x, 0.3, 1e-9);
    assert(close, "floating point needs a tolerance");
    io::printfn("0.1 + 0.2 ~= 0.3: %s", close);

    io::printfn("clamp(150) = %d, clamp(-5) = %d", math::clamp(150, 0, 100), math::clamp(-5, 0, 100));
    io::printfn("gcd = %d, lcm = %d, next pow2 = %d",
                math::gcd(12, 18), math::lcm(12, 18), math::next_power_of_2(100));
}
