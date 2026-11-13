// =====================================================================
//  e1102 · Примитивные тесты пересечений: AABB, круги, луч
// =====================================================================
//
//  Сначала прочитайте engine/docs/11_physics.md (раздел «Формы и тесты»).
//
//  Narrowphase начинается с простейших форм. Их тесты — это хлеб
//  физики, AI (видимость), рендера (отсечение) и геймплея (триггеры).
//  У каждого теста два «режима»:
//    * булев — «пересекаются ли?» (триггеры, broadphase, отсечение);
//    * с контактом — нормаль n и глубина проникновения depth, чтобы
//      солвер знал, КУДА и НАСКОЛЬКО расталкивать тела.
//
//  Соглашение этого курса: нормаль контакта направлена ОТ тела A К телу
//  B и единичной длины; depth > 0, когда тела перекрываются. Сдвинув B
//  на n * depth, мы их разведём.
//
//      AABB (min, max):            круг (c, r):
//        +--------+ max              .-~~-.
//        |        |                 /  c . \ r
//        +--------+                 \      /
//      min                           `-..-'
//
//  * AABB vs AABB: перекрытие по КАЖДОЙ оси (теорема о разделяющей оси
//    в самом простом виде). Касание (a.max.x == b.min.x) считаем
//    пересечением — так стабильнее для broadphase.
//  * Круг vs круг: сравнивайте КВАДРАТЫ расстояний (без sqrt), и только
//    при пересечении считайте sqrt для нормали. Совпавшие центры —
//    вырожденный случай: возьмите нормаль (0, 1), depth = ra + rb.
//  * Круг vs AABB: ближайшая точка коробки к центру — clamp центра в
//    [min, max]. Если центр ВНУТРИ коробки, clamp вернёт сам центр и
//    нормаль не определить: тогда выталкиваем по оси наименьшего
//    проникновения (как в Box2D/«Real-Time Collision Detection»).
//  * Луч vs AABB, slab-метод: для каждой оси параметры входа/выхода
//    t1 = (min - o) / d, t2 = (max - o) / d; tmin = max входов,
//    tmax = min выходов; попадание, если tmin <= tmax и tmax >= 0.
//    Деление на 0 при d.x == 0 даёт ±inf — и IEEE-754 всё делает
//    правильно (кроме случая 0 * inf, если начало луча ровно на грани).
//
//  ЗАДАЧА: реализуйте функции с TODO. Не меняйте сигнатуры и main().
//
import std::io, std::math;

alias Vec2 = float[<2>];

struct Aabb
{
    Vec2 min;
    Vec2 max;
}

struct Circle
{
    Vec2 c;
    float r;
}

struct Contact
{
    Vec2 normal;   // от A к B, единичная
    float depth;   // > 0 при перекрытии
}

fn bool aabb_overlap(Aabb a, Aabb b)
{
    return a.min.x <= b.max.x && b.min.x <= a.max.x
        && a.min.y <= b.max.y && b.min.y <= a.max.y;
}

fn bool circle_circle(Circle a, Circle b, Contact* out)
{
    Vec2 d = b.c - a.c;
    float rs = a.r + b.r;
    float dist2 = d.dot(d);
    if (dist2 > rs * rs) return false;
    if (dist2 == 0)
    {
        *out = { { 0, 1 }, rs };
        return true;
    }
    float dist = math::sqrt(dist2);
    *out = { d / dist, rs - dist };
    return true;
}

// A — коробка, B — круг: нормаль от коробки к кругу.
fn bool aabb_circle(Aabb a, Circle b, Contact* out)
{
    Vec2 p = { math::clamp(b.c.x, a.min.x, a.max.x), math::clamp(b.c.y, a.min.y, a.max.y) };
    Vec2 d = b.c - p;
    float dist2 = d.dot(d);
    if (dist2 > 0)
    {
        if (dist2 > b.r * b.r) return false;
        float dist = math::sqrt(dist2);
        *out = { d / dist, b.r - dist };
        return true;
    }
    // Центр внутри коробки: ищем ближайшую грань.
    float left = b.c.x - a.min.x;
    float right = a.max.x - b.c.x;
    float down = b.c.y - a.min.y;
    float up = a.max.y - b.c.y;
    float best = left;
    Vec2 n = { -1, 0 };
    if (right < best) { best = right; n = { 1, 0 }; }
    if (down < best) { best = down; n = { 0, -1 }; }
    if (up < best) { best = up; n = { 0, 1 }; }
    *out = { n, best + b.r };
    return true;
}

// Возвращает true и параметр t точки входа (t >= 0; если начало внутри — 0).
fn bool ray_aabb(Vec2 origin, Vec2 dir, Aabb box, float* t_hit)
{
    float tmin = 0;
    float tmax = float::inf;
    for (int i = 0; i < 2; i++)
    {
        float inv = 1.0f / dir[i];
        float t1 = (box.min[i] - origin[i]) * inv;
        float t2 = (box.max[i] - origin[i]) * inv;
        if (t1 > t2) { float tmp = t1; t1 = t2; t2 = tmp; }
        tmin = math::max(tmin, t1);
        tmax = math::min(tmax, t2);
        if (tmin > tmax) return false;
    }
    *t_hit = tmin;
    return true;
}

fn void print_contact(String what, bool hit, Contact c)
{
    if (!hit) { io::printfn("%-22s miss", what); return; }
    io::printfn("%-22s hit n=(%.3f, %.3f) depth=%.3f", what, c.normal.x, c.normal.y, c.depth);
}

fn void main()
{
    // --- AABB
    Aabb a = { { 0, 0 }, { 2, 2 } };
    assert(aabb_overlap(a, { { 1, 1 }, { 3, 3 } }));
    assert(aabb_overlap(a, { { 2, 0 }, { 3, 1 } }), "touching counts as overlap");
    assert(!aabb_overlap(a, { { 2.5f, 0 }, { 3, 1 } }), "separated on x");
    assert(!aabb_overlap(a, { { 0, 3 }, { 1, 4 } }), "separated on y");
    assert(!aabb_overlap(a, { { 3, 3 }, { 4, 4 } }), "separated on both");
    io::printn("aabb vs aabb           ok");

    // --- круг vs круг
    Contact c;
    bool hit = circle_circle({ { 0, 0 }, 3 }, { { 3, 4 }, 3 }, &c);
    assert(hit && math::abs(c.depth - 1.0f) < 1e-5f && math::abs(c.normal.x - 0.6f) < 1e-5f);
    print_contact("circle vs circle", hit, c);
    hit = circle_circle({ { 0, 0 }, 1 }, { { 3, 4 }, 3 }, &c);
    assert(!hit, "5 > 1 + 3: must miss");
    print_contact("circle vs circle far", hit, c);
    hit = circle_circle({ { 1, 1 }, 1 }, { { 1, 1 }, 2 }, &c);
    assert(hit && c.normal.y == 1.0f && c.depth == 3.0f, "coincident centers: n=(0,1), depth = ra+rb");
    print_contact("circle same center", hit, c);

    // --- AABB vs круг
    Aabb box = { { 0, 0 }, { 4, 2 } };
    hit = aabb_circle(box, { { 2, 2.5f }, 1 }, &c);          // над верхней гранью
    assert(hit && c.normal.y == 1.0f && math::abs(c.depth - 0.5f) < 1e-5f);
    print_contact("box vs circle top", hit, c);
    hit = aabb_circle(box, { { 7, 6 }, 5 }, &c);              // у угла (4,2): d = (3,4)
    assert(hit && math::abs(c.normal.x - 0.6f) < 1e-5f && math::abs(c.depth - 0.0f) < 1e-5f);
    print_contact("box vs circle corner", hit, c);
    hit = aabb_circle(box, { { 7.1f, 6 }, 5 }, &c);
    assert(!hit, "corner just out of reach");
    print_contact("box vs circle far", hit, c);
    hit = aabb_circle(box, { { 3.5f, 1 }, 0.25f }, &c);       // центр внутри, ближе к правой грани
    assert(hit && c.normal.x == 1.0f && math::abs(c.depth - 0.75f) < 1e-5f, "deep penetration: push out via nearest face");
    print_contact("box vs circle inside", hit, c);

    // --- луч vs AABB
    float t;
    Aabb target = { { 2, -1 }, { 4, 1 } };
    hit = ray_aabb({ 0, 0 }, { 1, 0 }, target, &t);
    assert(hit && t == 2.0f);
    io::printfn("ray +x                 t=%.3f", t);
    hit = ray_aabb({ 0, 3 }, { 1, -1 }, target, &t);          // входит через верх при x=2..4
    assert(hit && t == 2.0f);
    io::printfn("ray diagonal           t=%.3f", t);
    assert(!ray_aabb({ 0, 2 }, { 1, 0 }, target, &t), "parallel ray above the box");
    assert(!ray_aabb({ 0, 0 }, { -1, 0 }, target, &t), "box is behind the ray");
    assert(ray_aabb({ 3, 0 }, { 0, 1 }, target, &t) && t == 0.0f, "origin inside -> t = 0");
    io::printn("ray misses             ok");
    io::printn("all collision tests passed");
}
