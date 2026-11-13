// =====================================================================
//  E0404 · Интерполяция поворотов: nlerp и slerp
// =====================================================================
//
//  Сначала прочитайте engine/docs/04_math.md (раздел 5).
//
//  nlerp(a, b, t) = normalize(a + (b - a) * t)
//      дёшево, путь по правильной дуге, но угловая скорость
//      неравномерна: в середине быстрее, на краях медленнее.
//
//  slerp(a, b, t) = a * sin((1-t)W)/sin W + b * sin(tW)/sin W,
//      где cos W = dot(a, b) — постоянная угловая скорость.
//
//  Обе функции обязаны:
//    * идти КОРОТКИМ путём: q и -q — один поворот, поэтому если
//      dot(a, b) < 0, заменяем b на -b (иначе поворот на 30 градусов
//      превратится в путь на 330);
//    * slerp при почти совпадающих кватернионах (dot > 0.9995)
//      переключается на nlerp: sin W ~ 0, делить на него нельзя.
//
//  angle_between(a, b) — угол поворота от a к b: 2 * acos(|dot(a, b)|),
//  аргумент acos обязательно кламповать в [-1, 1] — из-за округления
//  dot единичных кватернионов бывает 1.0000001, и acos даёт NaN.
//
//  ЗАДАЧА: реализуйте angle_between, nlerp, slerp.
//
import std::io, std::math;

alias Vec3 = float[<3>];
alias Quat = float[<4>];

fn Quat from_axis_angle(Vec3 n, float angle)
{
    float s = math::sin(angle * 0.5f);
    return { n.x * s, n.y * s, n.z * s, math::cos(angle * 0.5f) };
}

fn float qdot(Quat a, Quat b) => (a * b).sum();
fn Quat qnormalize(Quat q) => q / math::sqrt(qdot(q, q));

fn float angle_between(Quat a, Quat b)
{
    float d = math::abs(qdot(a, b));
    if (d > 1.0f) d = 1.0f;
    return 2.0f * math::acos(d);
}

fn Quat nlerp(Quat a, Quat b, float t)
{
    if (qdot(a, b) < 0) b = -b;
    return qnormalize(a + (b - a) * t);
}

fn Quat slerp(Quat a, Quat b, float t)
{
    float d = qdot(a, b);
    if (d < 0)
    {
        b = -b;
        d = -d;
    }
    if (d > 0.9995f) return nlerp(a, b, t);
    float w = math::acos(d);
    float s = math::sin(w);
    return a * (math::sin((1 - t) * w) / s) + b * (math::sin(t * w) / s);
}

// ---------------------------------------------------------------------

fn bool near4(Quat a, Quat b) => math::abs(a - b).max() < 1e-4f;

fn void main()
{
    const float PI = (float)math::PI;
    const float DEG = PI / 180;
    Vec3 up = { 0, 1, 0 };
    Quat a = from_axis_angle(up, 0);
    Quat b = from_axis_angle(up, 160 * DEG);

    assert(math::abs(angle_between(a, b) - 160 * DEG) < 1e-3f, "angle_between");
    assert(angle_between(b, b) == 0.0f, "acos argument must be clamped (no NaN)");
    assert(near4(slerp(a, b, 0), a) && near4(slerp(a, b, 1), b), "slerp endpoints");
    assert(near4(nlerp(a, b, 0), a) && near4(nlerp(a, b, 1), b), "nlerp endpoints");

    // Угловая скорость: 10 равных шагов по t.
    float smin = 1000; float smax = 0; float nmin = 1000; float nmax = 0;
    io::printf("slerp steps (deg):");
    for (int i = 0; i < 10; i++)
    {
        float t0 = (float)i / 10.0f;
        float t1 = (float)(i + 1) / 10.0f;
        float ds = angle_between(slerp(a, b, t0), slerp(a, b, t1)) / DEG;
        float dn = angle_between(nlerp(a, b, t0), nlerp(a, b, t1)) / DEG;
        io::printf(" %.1f", ds);
        smin = math::min(smin, ds); smax = math::max(smax, ds);
        nmin = math::min(nmin, dn); nmax = math::max(nmax, dn);
        Quat q = slerp(a, b, t1);
        assert(math::abs(qdot(q, q) - 1) < 1e-4f, "slerp result must be unit length");
    }
    io::printn();
    io::printfn("slerp step range %.2f..%.2f deg, nlerp %.2f..%.2f deg", smin, smax, nmin, nmax);
    assert(smax - smin < 0.05f, "slerp must have constant angular velocity");
    assert(nmax / nmin > 1.3f, "nlerp is not constant speed for big angles");

    // Короткий путь: c и -c — один поворот, результат должен совпасть.
    Quat c = from_axis_angle(up, 30 * DEG);
    Quat m1 = slerp(a, c, 0.5f);
    Quat m2 = slerp(a, -c, 0.5f);
    io::printfn("halfway to 30 deg: %.2f deg (via -q: %.2f deg)", angle_between(a, m1) / DEG, angle_between(a, m2) / DEG);
    assert(math::abs(angle_between(a, m2) - 15 * DEG) < 1e-3f, "slerp must take the short path");
    assert(math::abs(angle_between(a, nlerp(a, -c, 0.5f)) - 15 * DEG) < 1e-3f, "nlerp must take the short path");

    // Почти одинаковые кватернионы: без деления на ~0.
    Quat e = from_axis_angle(up, 0.001f * DEG);
    Quat me = slerp(a, e, 0.5f);
    assert(me == me, "NaN in slerp for tiny angles");   // NaN != NaN
    assert(angle_between(a, me) <= angle_between(a, e) + 1e-6f);
    io::printn("slerp OK");
}
