// =====================================================================
//  E0405 · Трансформ TRS, иерархии и AABB
// =====================================================================
//
//  Сначала прочитайте engine/docs/04_math.md (разделы 6–7).
//
//  Объекты сцены хранят не матрицу, а TRS: позицию, поворот
//  (кватернион) и масштаб (здесь однородный — один float). Матрица
//  строится по требованию: M = T * R * S.
//
//  Применить TRS к точке:  p' = pos + rotate(rot, p * scale)
//
//  Композиция «родитель * ребёнок» (сначала ребёнок, потом родитель):
//      scale = parent.scale * child.scale
//      rot   = parent.rot * child.rot             (qmul)
//      pos   = parent.pos + rotate(parent.rot, child.pos * parent.scale)
//
//  Обратный TRS (однородный масштаб):
//      rot   = conj(t.rot)
//      scale = 1 / t.scale
//      pos   = -rotate(inv.rot, t.pos) * inv.scale
//
//  AABB после преобразования матрицей (метод Arvo): новый центр —
//  преобразованный центр, новые полуразмеры:
//      e'[i] = sum_j |M[i][j]| * e[j]     (M[i][j] = cols[j][i], j < 3)
//  Это самый маленький AABB, содержащий повёрнутый бокс.
//
//  ЗАДАЧА: реализуйте Transform.apply, compose, inverse, Transform.to_mat4
//  и aabb_transform.
//
import std::io, std::math;

alias Vec3 = float[<3>];
alias Vec4 = float[<4>];
alias Quat = float[<4>];

// ---- готовые помощники из E0402/E0403 ----
struct Mat4 { Vec4[4] cols; }
fn Vec4 mul_vec(Mat4 m, Vec4 v) => m.cols[0] * v.x + m.cols[1] * v.y + m.cols[2] * v.z + m.cols[3] * v.w;
fn Mat4 mul(Mat4 a, Mat4 b)
{
    Mat4 r;
    for (int j = 0; j < 4; j++) r.cols[j] = mul_vec(a, b.cols[j]);
    return r;
}
fn float dot3(Vec3 a, Vec3 b) => (a * b).sum();
fn Vec3 cross(Vec3 a, Vec3 b) => a.yzx * b.zxy - a.zxy * b.yzx;
fn Quat from_axis_angle(Vec3 n, float angle)
{
    float s = math::sin(angle * 0.5f);
    return { n.x * s, n.y * s, n.z * s, math::cos(angle * 0.5f) };
}
fn Quat qmul(Quat a, Quat b)
{
    Vec3 v = b.xyz * a.w + a.xyz * b.w + cross(a.xyz, b.xyz);
    return { v.x, v.y, v.z, a.w * b.w - dot3(a.xyz, b.xyz) };
}
fn Quat conj(Quat q) => { -q.x, -q.y, -q.z, q.w };
fn Vec3 rotate(Quat q, Vec3 p)
{
    Vec3 t = cross(q.xyz, p) * 2.0f;
    return p + t * q.w + cross(q.xyz, t);
}
// -------------------------------------------

struct Transform
{
    Vec3 pos;
    Quat rot;
    float scale;
}

const Transform IDENTITY = { { 0, 0, 0 }, { 0, 0, 0, 1 }, 1 };

fn Vec3 Transform.apply(&self, Vec3 p)
{
    return self.pos + rotate(self.rot, p * self.scale);
}

fn Transform compose(Transform parent, Transform child)
{
    return {
        parent.pos + rotate(parent.rot, child.pos * parent.scale),
        qmul(parent.rot, child.rot),
        parent.scale * child.scale,
    };
}

fn Transform inverse(Transform t)
{
    Transform inv;
    inv.rot = conj(t.rot);
    inv.scale = 1.0f / t.scale;
    inv.pos = -rotate(inv.rot, t.pos) * inv.scale;
    return inv;
}

fn Mat4 Transform.to_mat4(&self)
{
    Vec3 x = rotate(self.rot, { self.scale, 0, 0 });
    Vec3 y = rotate(self.rot, { 0, self.scale, 0 });
    Vec3 z = rotate(self.rot, { 0, 0, self.scale });
    return { { { x.x, x.y, x.z, 0 }, { y.x, y.y, y.z, 0 }, { z.x, z.y, z.z, 0 },
               { self.pos.x, self.pos.y, self.pos.z, 1 } } };
}

struct Aabb
{
    Vec3 min;
    Vec3 max;
}

fn Aabb aabb_transform(Mat4 m, Aabb b)
{
    Vec3 c = (b.min + b.max) * 0.5f;
    Vec3 e = (b.max - b.min) * 0.5f;
    Vec3 nc = mul_vec(m, { c.x, c.y, c.z, 1 }).xyz;
    Vec3 ne = math::abs(m.cols[0].xyz) * e.x + math::abs(m.cols[1].xyz) * e.y + math::abs(m.cols[2].xyz) * e.z;
    return { nc - ne, nc + ne };
}

// ---------------------------------------------------------------------

fn bool near3(Vec3 a, Vec3 b, float eps = 1e-4f) => math::abs(a - b).max() < eps;

fn bool near_m(Mat4 a, Mat4 b)
{
    for (int i = 0; i < 4; i++) if (math::abs(a.cols[i] - b.cols[i]).max() > 1e-4f) return false;
    return true;
}

fn void show(String name, Vec3 v)
{
    for (int i = 0; i < 3; i++) if (math::abs(v[i]) < 5e-4f) v[i] = 0;
    io::printfn("%-14s (%.3f, %.3f, %.3f)", name, v.x, v.y, v.z);
}

fn void main()
{
    const float PI = (float)math::PI;
    Vec3 up = { 0, 0, 1 };

    Transform t = { { 10, 0, 0 }, from_axis_angle(up, PI / 2), 2 };
    show("apply (1,0,0)", t.apply({ 1, 0, 0 }));
    assert(near3(t.apply({ 1, 0, 0 }), { 10, 2, 0 }), "scale, then rotate, then translate");
    assert(near3(IDENTITY.apply({ 1, 2, 3 }), { 1, 2, 3 }));

    // Солнце -> Земля -> Луна.
    Transform sun = { { 100, 0, 0 }, from_axis_angle(up, PI / 4), 1 };
    Transform earth = { { 50, 0, 0 }, from_axis_angle(up, PI / 2), 0.5f };
    Transform moon = { { 10, 0, 0 }, from_axis_angle(up, 0), 0.25f };
    Transform earth_w = compose(sun, earth);
    Transform moon_w = compose(earth_w, moon);
    show("earth world", earth_w.pos);
    show("moon world", moon_w.pos);
    io::printfn("moon scale %.4f", moon_w.scale);
    Vec3 p = { 1, 1, 1 };
    assert(near3(moon_w.apply(p), sun.apply(earth.apply(moon.apply(p)))), "compose = apply child, then parent");
    assert(near3(compose(compose(sun, earth), moon).apply(p), compose(sun, compose(earth, moon)).apply(p)), "associativity");

    // Матрицы: TRS -> Mat4 и композиция совпадают с произведением матриц.
    Mat4 m = moon_w.to_mat4();
    assert(near3(mul_vec(m, { p.x, p.y, p.z, 1 }).xyz, moon_w.apply(p)), "to_mat4 must agree with apply");
    assert(near_m(compose(sun, earth).to_mat4(), mul(sun.to_mat4(), earth.to_mat4())), "compose = matrix product");

    // Обратный трансформ.
    Transform inv = inverse(moon_w);
    // Точность: координаты ~130, обратный масштаб 8 -> погрешность ~1e-4.
    assert(near3(inv.apply(moon_w.apply(p)), p, 2e-3f), "inverse undoes the transform");
    assert(near3(compose(moon_w, inv).apply(p), p, 2e-3f));
    show("moon -> local", inv.apply({ 0, 0, 0 }));

    // AABB поворачиваем на 45 градусов вокруг Z.
    Aabb box = { { -1, -2, -3 }, { 1, 2, 3 } };
    Transform rt = { { 5, 0, 0 }, from_axis_angle(up, PI / 4), 1 };
    Mat4 rm = rt.to_mat4();
    Aabb wb = aabb_transform(rm, box);
    show("aabb min", wb.min);
    show("aabb max", wb.max);
    // Все 8 углов внутри, и бокс плотный (хотя бы один угол на каждой грани).
    Vec3 lo = { 1e9, 1e9, 1e9 };
    Vec3 hi = { -1e9, -1e9, -1e9 };
    for (int i = 0; i < 8; i++)
    {
        Vec3 corner = { i & 1 ? box.max.x : box.min.x, i & 2 ? box.max.y : box.min.y, i & 4 ? box.max.z : box.min.z };
        Vec3 w = rt.apply(corner);
        lo = math::min(lo, w);
        hi = math::max(hi, w);
    }
    assert(near3(lo, wb.min) && near3(hi, wb.max), "Arvo AABB must be exactly the bounds of the corners");
    io::printn("transforms OK");
}
