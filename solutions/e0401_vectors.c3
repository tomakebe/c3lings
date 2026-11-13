// =====================================================================
//  E0401 · Вектора на SIMD-типах
// =====================================================================
//
//  Сначала прочитайте engine/docs/04_math.md (раздел 1).
//
//  `float[<3>]` — встроенный векторный тип C3: арифметика поэлементная
//  (SIMD), есть swizzle (`v.zxy`, `v.xy`) и редукции (`v.sum()`).
//  Мы называем его `alias Vec3 = float[<3>];` и пишем свободные функции
//  (у typedef'а над вектором swizzle возвращает базовый тип, и
//  получается много кастов — поэтому alias).
//
//      a * b          поэлементно:  (ax*bx, ay*by, az*bz)
//      a * 2.0f       на скаляр
//      (a * b).sum()  скалярное произведение
//      a.yzx          перестановка компонент
//
//  Векторное произведение без единого скалярного умножения:
//      cross(a, b) = a.yzx * b.zxy - a.zxy * b.yzx
//  (распишите x-компоненту и убедитесь: ay*bz - az*by).
//
//  normalize нулевого вектора — деление на ноль и NaN, который потом
//  расползётся по всей сцене. Наша версия возвращает ноль, если длина
//  меньше 1e-8.
//
//  approx_eq: float нельзя сравнивать через ==. Используем
//  |a - b| <= eps поэлементно (bool-вектор и проверка всех компонент).
//
//  ЗАДАЧА: реализуйте dot, cross, length, normalize, lerp, approx_eq,
//  reflect (отражение v от поверхности с единичной нормалью n:
//  v - 2 * dot(v, n) * n).
//
import std::io, std::math;

alias Vec3 = float[<3>];

fn float dot(Vec3 a, Vec3 b)
{
    return (a * b).sum();
}

fn Vec3 cross(Vec3 a, Vec3 b)
{
    return a.yzx * b.zxy - a.zxy * b.yzx;
}

fn float length(Vec3 v)
{
    return math::sqrt(dot(v, v));
}

fn Vec3 normalize(Vec3 v)
{
    float len = length(v);
    if (len < 1e-8f) return { 0, 0, 0 };
    return v / len;
}

fn Vec3 lerp(Vec3 a, Vec3 b, float t)
{
    return a + (b - a) * t;
}

fn bool approx_eq(Vec3 a, Vec3 b, float eps = 1e-5f)
{
    Vec3 d = math::abs(a - b);
    return d.x <= eps && d.y <= eps && d.z <= eps;
}

fn Vec3 reflect(Vec3 v, Vec3 n)
{
    return v - n * (2.0f * dot(v, n));
}

// Печать без "-0.000": прибавление +0.0 превращает -0.0 в +0.0.
fn void show(String name, Vec3 v)
{
    v += (Vec3){ 0, 0, 0 };
    io::printfn("%-10s (%.3f, %.3f, %.3f)", name, v.x, v.y, v.z);
}

fn void main()
{
    Vec3 x = { 1, 0, 0 };
    Vec3 y = { 0, 1, 0 };
    Vec3 z = { 0, 0, 1 };
    Vec3 a = { 1, 2, 3 };
    Vec3 b = { -4, 5, 0.5f };

    assert(dot(a, b) == 7.5f, "dot");
    assert(approx_eq(cross(x, y), z) && approx_eq(cross(y, z), x) && approx_eq(cross(z, x), y), "right-handed basis");
    assert(approx_eq(cross(y, x), -z), "cross is anti-commutative");
    Vec3 c = cross(a, b);
    assert(math::abs(dot(c, a)) < 1e-4f && math::abs(dot(c, b)) < 1e-4f, "cross is perpendicular to both");
    show("cross", c);

    assert(length((Vec3){ 3, 4, 0 }) == 5.0f && length((Vec3){ 0, 0, 0 }) == 0.0f);
    Vec3 n = normalize(a);
    assert(math::abs(length(n) - 1.0f) < 1e-6f, "normalized length is 1");
    assert(normalize((Vec3){ 0, 0, 0 }) == (Vec3){ 0, 0, 0 }, "normalize(0) must be 0, not NaN");
    show("normalize", n);

    assert(approx_eq(lerp(a, b, 0), a) && approx_eq(lerp(a, b, 1), b));
    show("lerp 0.25", lerp(a, b, 0.25f));

    assert(!approx_eq(a, a + (Vec3){ 0, 0, 0.001f }) && approx_eq(a, a + (Vec3){ 0, 0, 0.000001f }));

    // Мяч летит вниз-вправо и отскакивает от пола (нормаль +Y).
    Vec3 r = reflect((Vec3){ 3, -2, 0 }, y);
    assert(approx_eq(r, (Vec3){ 3, 2, 0 }), "reflect");
    show("reflect", r);
    // От наклонной стены.
    Vec3 wall = normalize((Vec3){ -1, 1, 0 });
    Vec3 r2 = reflect((Vec3){ 1, 0, 0 }, wall);
    assert(approx_eq(r2, (Vec3){ 0, 1, 0 }), "reflect from a 45 degree wall");
    show("reflect45", r2);

    // Площадь треугольника = половина длины векторного произведения.
    Vec3 p0 = { 0, 0, 0 };
    Vec3 p1 = { 4, 0, 0 };
    Vec3 p2 = { 0, 3, 0 };
    float area = length(cross(p1 - p0, p2 - p0)) * 0.5f;
    io::printfn("triangle area %.3f", area);
    assert(area == 6.0f);
    io::printn("vectors OK");
}
