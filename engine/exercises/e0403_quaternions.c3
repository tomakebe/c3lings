// =====================================================================
//  E0403 · Кватернионы
// =====================================================================
//
//  Сначала прочитайте engine/docs/04_math.md (раздел 4).
//
//  Кватернион храним как float[<4>]: xyz — векторная часть v, w —
//  скалярная. Единичный кватернион поворота на угол a вокруг единичной
//  оси n:
//      q = ( n * sin(a/2),  cos(a/2) )
//
//  Произведение Гамильтона:
//      q1 * q2 = ( w1*v2 + w2*v1 + cross(v1, v2),   w1*w2 - dot(v1, v2) )
//  Оно НЕ коммутативно. Повернуть сначала q1, потом q2 — это q2 * q1
//  (как с матрицами при векторах-столбцах).
//
//  Сопряжение: conj(q) = (-v, w). Для единичного q это обратный поворот.
//
//  Поворот вектора p (быстрая форма, без двух полных произведений):
//      t  = 2 * cross(v, p)
//      p' = p + w * t + cross(v, t)
//
//  В матрицу (столбцы — образы базисных векторов):
//      cols[0] = rotate(q, X), cols[1] = rotate(q, Y), cols[2] = rotate(q, Z)
//  (можно и явной формулой — главное, чтобы совпало с rotate).
//
//  ЗАДАЧА: реализуйте from_axis_angle, qmul, conj, qnormalize, rotate,
//  to_mat4.
//
import std::io, std::math;

alias Vec3 = float[<3>];
alias Vec4 = float[<4>];
alias Quat = float[<4>];

struct Mat4 { Vec4[4] cols; }

fn Vec4 mul_vec(Mat4 m, Vec4 v) => m.cols[0] * v.x + m.cols[1] * v.y + m.cols[2] * v.z + m.cols[3] * v.w;
fn float dot3(Vec3 a, Vec3 b) => (a * b).sum();
fn Vec3 cross(Vec3 a, Vec3 b) => a.yzx * b.zxy - a.zxy * b.yzx;

const Quat QUAT_IDENTITY = { 0, 0, 0, 1 };

fn Quat from_axis_angle(Vec3 axis, float angle)
{
    // TODO: нормализовать ось; (n * sin(a/2), cos(a/2))
    return QUAT_IDENTITY;
}

fn Quat qmul(Quat a, Quat b)
{
    // TODO: произведение Гамильтона
    return a;
}

fn Quat conj(Quat q)
{
    // TODO
    return q;
}

fn Quat qnormalize(Quat q)
{
    // TODO
    return q;
}

fn Vec3 rotate(Quat q, Vec3 p)
{
    // TODO: быстрая форма через t = 2 * cross(v, p)
    return p;
}

fn Mat4 to_mat4(Quat q)
{
    // TODO: столбцы — повёрнутые базисные вектора, cols[3] = (0,0,0,1)
    return { { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } } };
}

// ---------------------------------------------------------------------

fn bool near3(Vec3 a, Vec3 b, float eps = 1e-5f) => math::abs(a - b).max() < eps;
fn bool near4(Vec4 a, Vec4 b, float eps = 1e-5f) => math::abs(a - b).max() < eps;

fn void show(String name, Vec4 v)
{
    for (int i = 0; i < 4; i++) if (math::abs(v[i]) < 5e-4f) v[i] = 0;
    io::printfn("%-18s (%.3f, %.3f, %.3f, %.3f)", name, v.x, v.y, v.z, v.w);
}

fn void main()
{
    const float PI = (float)math::PI;
    Vec3 x = { 1, 0, 0 };
    Vec3 y = { 0, 1, 0 };
    Vec3 z = { 0, 0, 1 };

    Quat rz = from_axis_angle(z, PI / 2);
    show("90 deg around Z", rz);
    assert(near4(rz, { 0, 0, math::sqrt(0.5f), math::sqrt(0.5f) }));
    assert(near4(from_axis_angle({ 0, 0, 5 }, PI / 2), rz), "axis must be normalized inside");

    assert(near3(rotate(rz, x), y), "Z-rotation maps X to Y");
    assert(near3(rotate(QUAT_IDENTITY, { 1, 2, 3 }), { 1, 2, 3 }));
    assert(near4(qmul(QUAT_IDENTITY, rz), rz) && near4(qmul(rz, QUAT_IDENTITY), rz));

    // Композиция: сначала 90 вокруг Z, потом 90 вокруг X.
    Quat rx = from_axis_angle(x, PI / 2);
    Quat both = qmul(rx, rz);
    Vec3 p = rotate(both, x);
    show("rx*rz applied to X", { p.x, p.y, p.z, 0 });
    assert(near3(p, rotate(rx, rotate(rz, x))), "q2*q1 = first q1, then q2");
    assert(near3(p, z), "X -> Y (around Z) -> Z (around X)");
    assert(!near4(qmul(rx, rz), qmul(rz, rx)), "quaternion product is not commutative");

    // Сопряжённый — обратный поворот; q и -q — один и тот же поворот.
    assert(near4(qmul(rz, conj(rz)), QUAT_IDENTITY));
    assert(near3(rotate(conj(rz), y), x));
    assert(near3(rotate(-both, { 1, 2, 3 }), rotate(both, { 1, 2, 3 })), "double cover: q and -q");
    // Поворот на 360 градусов даёт q = -identity.
    show("360 deg around Y", from_axis_angle(y, 2 * PI));

    // Матрица из кватерниона совпадает с rotate.
    Quat q = qnormalize({ 0.3f, -0.5f, 0.2f, 0.8f });
    assert(math::abs((q * q).sum() - 1.0f) < 1e-6f);
    Mat4 m = to_mat4(q);
    Vec3 v = { 1.5f, -2, 0.25f };
    Vec3 by_m = mul_vec(m, { v.x, v.y, v.z, 1 }).xyz;
    assert(near3(by_m, rotate(q, v)), "to_mat4 must agree with rotate");
    show("m.cols[0]", m.cols[0]);
    // Поворот сохраняет длину.
    assert(math::abs(dot3(rotate(q, v), rotate(q, v)) - dot3(v, v)) < 1e-4f);

    // 1000 маленьких поворотов с перенормализацией.
    Quat step = from_axis_angle({ 1, 1, 0 }, PI / 500);
    Quat acc = QUAT_IDENTITY;
    for (int i = 0; i < 1000; i++) acc = qnormalize(qmul(step, acc));
    show("1000 x 0.36 deg", acc);
    assert(near4(acc, QUAT_IDENTITY, 1e-3f) || near4(acc, -QUAT_IDENTITY, 1e-3f), "a full turn -> identity (up to sign)");
    io::printn("quaternions OK");
}
