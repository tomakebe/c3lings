// =====================================================================
//  e1105 · Разрешение контактов импульсами: упругость, трение, вращение
// =====================================================================
//
//  Сначала прочитайте engine/docs/11_physics.md (раздел «Разрешение
//  контактов»).
//
//  Narrowphase сказал: тела A и B касаются в точке p с нормалью n (от A
//  к B) и глубиной depth. Теперь солвер должен (1) не дать им двигаться
//  навстречу и (2) вытолкнуть их друг из друга.
//
//  1) Скоростной шаг — ИМПУЛЬС. Скорость точки контакта тела:
//         v_p = v + w × r,   r = p - pos,   w × r = (-w*r.y, w*r.x)
//     Относительная скорость vr = v_pB - v_pA, нормальная часть
//     vn = dot(vr, n). Если vn > 0 — тела уже расходятся, ничего не
//     делаем. Иначе прикладываем импульс j вдоль n:
//
//         j = -(1 + e) * vn / K,
//         K = invM_A + invM_B + (rA × n)² * invI_A + (rB × n)² * invI_B
//
//     e — коэффициент восстановления (restitution, берём min(eA, eB)),
//     K — «обратная эффективная масса» вдоль n: она учитывает, что часть
//     импульса уходит во вращение. Импульс P = j*n прикладывается к B
//     и -P к A:
//         v += P * invM;     w += invI * (r × P)
//
//  2) Трение по Кулону. После нормального импульса пересчитайте vr,
//     касательная t = нормализованная (vr - n*dot(vr, n)); если она
//     почти нулевая — трения нет. Импульс трения
//         jt = -dot(vr, t) / Kt   (Kt — как K, но с t вместо n)
//     и он ОГРАНИЧЕН конусом трения: |jt| <= mu * j, mu = sqrt(muA*muB).
//     Если ограничение не сработало — тело в «сцеплении» (точка контакта
//     перестаёт скользить: катится!), если сработало — скользит.
//
//  3) Позиционная коррекция. Импульсы чинят скорости, но не уже
//     случившееся проникновение. Простейший способ — сдвинуть тела
//     вдоль n пропорционально обратным массам:
//         corr = max(depth - SLOP, 0) / (invM_A + invM_B) * PERCENT
//         posA -= n * corr * invM_A;   posB += n * corr * invM_B
//     SLOP (допустимое проникновение) убирает дрожание, PERCENT < 1 —
//     чтобы не перелетать. (Box2D делает то же через «псевдоскорости»
//     или Baumgarte-член в самом импульсе.)
//
//  Статическое тело — это просто invM = invI = 0: формулы его не сдвинут.
//
//  ЗАДАЧА: реализуйте `apply_impulse`, `resolve_contact` и
//  `positional_correction`.
//
import std::io, std::math;

alias Vec2 = float[<2>];

const float SLOP = 0.01f;
const float PERCENT = 0.8f;

struct Body
{
    Vec2 pos;
    Vec2 vel;
    float w;             // угловая скорость (рад/с, против часовой > 0)
    float inv_mass;
    float inv_inertia;
    float restitution;
    float friction;
}

struct Contact
{
    Vec2 normal;   // от A к B
    float depth;
    Vec2 point;
}

fn float cross(Vec2 a, Vec2 b) => a.x * b.y - a.y * b.x;
fn Vec2 cross_sv(float w, Vec2 r) => { -w * r.y, w * r.x };

fn Body make_disc(Vec2 pos, float mass, float radius, float e, float mu)
{
    if (mass == 0) return { .pos = pos, .restitution = e, .friction = mu };
    float inertia = 0.5f * mass * radius * radius;   // сплошной диск
    return { .pos = pos, .inv_mass = 1 / mass, .inv_inertia = 1 / inertia, .restitution = e, .friction = mu };
}

fn void apply_impulse(Body* b, Vec2 impulse, Vec2 r)
{
    b.vel += impulse * b.inv_mass;
    b.w += b.inv_inertia * cross(r, impulse);
}

fn Vec2 relative_velocity(Body* a, Body* b, Vec2 ra, Vec2 rb)
{
    return (b.vel + cross_sv(b.w, rb)) - (a.vel + cross_sv(a.w, ra));
}

// Возвращает нормальный импульс j (0, если тела расходятся).
fn float resolve_contact(Body* a, Body* b, Contact c)
{
    Vec2 n = c.normal;
    Vec2 ra = c.point - a.pos;
    Vec2 rb = c.point - b.pos;
    Vec2 vr = relative_velocity(a, b, ra, rb);
    float vn = vr.dot(n);
    if (vn > 0) return 0;

    float ran = cross(ra, n);
    float rbn = cross(rb, n);
    float k = a.inv_mass + b.inv_mass + ran * ran * a.inv_inertia + rbn * rbn * b.inv_inertia;
    if (k == 0) return 0;
    float e = math::min(a.restitution, b.restitution);
    float j = -(1 + e) * vn / k;
    apply_impulse(a, -n * j, ra);
    apply_impulse(b, n * j, rb);

    // Трение.
    vr = relative_velocity(a, b, ra, rb);
    Vec2 t = vr - n * vr.dot(n);
    float tl = t.length();
    if (tl < 1e-6f) return j;
    t /= tl;
    float rat = cross(ra, t);
    float rbt = cross(rb, t);
    float kt = a.inv_mass + b.inv_mass + rat * rat * a.inv_inertia + rbt * rbt * b.inv_inertia;
    float jt = -vr.dot(t) / kt;
    float mu = math::sqrt(a.friction * b.friction);
    jt = math::clamp(jt, -mu * j, mu * j);
    apply_impulse(a, -t * jt, ra);
    apply_impulse(b, t * jt, rb);
    return j;
}

fn void positional_correction(Body* a, Body* b, Contact c)
{
    float inv_sum = a.inv_mass + b.inv_mass;
    if (inv_sum == 0) return;
    float corr = math::max(c.depth - SLOP, 0.0f) / inv_sum * PERCENT;
    a.pos -= c.normal * (corr * a.inv_mass);
    b.pos += c.normal * (corr * b.inv_mass);
}

// ------------------------------------------------------------------ тесты
fn bool near(float a, float b) => math::abs(a - b) < 1e-4f;
fn float momentum_x(Body* a, Body* b) => a.vel.x / a.inv_mass + b.vel.x / b.inv_mass;

fn void main()
{
    // 1. Лобовое столкновение равных масс, e = 1: скорости меняются местами.
    Body a = make_disc({ 0, 0 }, 1, 0.5f, 1, 0);
    Body b = make_disc({ 1, 0 }, 1, 0.5f, 1, 0);
    a.vel = { 2, 0 };
    b.vel = { -1, 0 };
    Contact c = { { 1, 0 }, 0, { 0.5f, 0 } };
    float j = resolve_contact(&a, &b, c);
    assert(near(j, 3) && near(a.vel.x, -1) && near(b.vel.x, 2), "elastic swap");
    io::printfn("elastic:      j=%.3f  va=%.3f  vb=%.3f", j, a.vel.x, b.vel.x);

    // 2. Повторный вызов: тела уже расходятся — импульса нет.
    j = resolve_contact(&a, &b, c);
    assert(j == 0 && near(a.vel.x, -1), "separating bodies must be left alone");
    io::printn("separating:   no impulse");

    // 3. Разные массы, e = 0.5: импульс сохраняется, vr' = -e * vr.
    a = make_disc({ 0, 0 }, 3, 0.5f, 0.5f, 0);
    b = make_disc({ 1, 0 }, 1, 0.5f, 0.8f, 0);
    a.vel = { 1, 0 };
    b.vel = { -3, 0 };
    float p0 = momentum_x(&a, &b);
    j = resolve_contact(&a, &b, c);
    assert(near(momentum_x(&a, &b), p0), "momentum must be conserved");
    assert(near(b.vel.x - a.vel.x, 2), "relative velocity after = -e * before");
    io::printfn("inelastic:    j=%.3f  va=%.3f  vb=%.3f  p=%.3f", j, a.vel.x, b.vel.x, math::abs(momentum_x(&a, &b)));

    // 4. Диск падает и скользит по статическому полу, mu = 0.5:
    //    трение упирается в конус и диск только начинает вращаться.
    Body ground = make_disc({ 0, -10 }, 0, 0, 0, 0.5f);
    Body ball = make_disc({ 0, 0.5f }, 1, 0.5f, 0, 0.5f);
    ball.vel = { 4, -1 };
    Contact gc = { { 0, 1 }, 0, { 0, 0 } };
    j = resolve_contact(&ground, &ball, gc);
    assert(near(j, 1) && near(ball.vel.y, 0) && near(ball.vel.x, 3.5f) && near(ball.w, -2), "sliding friction is clamped by mu * j");
    assert(ground.vel.x == 0 && ground.w == 0, "static body must not move");
    io::printfn("slide mu=0.5: v=(%.3f, %.3f)  w=%.3f", ball.vel.x, ball.vel.y + 0.0f, ball.w);

    // 5. То же, но mu = 2: трение не упирается в конус — диск сразу КАТИТСЯ
    //    (скорость точки контакта = 0, v = 2/3 * v0 для сплошного диска).
    ground.friction = 2;
    ball = make_disc({ 0, 0.5f }, 1, 0.5f, 0, 2);
    ball.vel = { 4, -1 };
    resolve_contact(&ground, &ball, gc);
    Vec2 contact_vel = ball.vel + cross_sv(ball.w, gc.point - ball.pos);
    assert(near(contact_vel.x, 0) && near(ball.vel.x, 8.0f / 3), "with enough friction the disc must roll");
    io::printfn("roll mu=2:    v=(%.3f, %.3f)  w=%.3f  contact v=%.3f", ball.vel.x, ball.vel.y + 0.0f, ball.w, math::abs(contact_vel.x));

    // 6. Позиционная коррекция: (0.1 - 0.01) * 0.8 = 0.072, делится по обратным массам.
    a = make_disc({ 0, 0 }, 1, 0.5f, 0, 0);
    b = make_disc({ 0.9f, 0 }, 3, 0.5f, 0, 0);
    positional_correction(&a, &b, { { 1, 0 }, 0.1f, { 0.45f, 0 } });
    assert(near(a.pos.x, -0.054f) && near(b.pos.x, 0.918f), "correction is split by inverse mass");
    positional_correction(&ground, &ball, { { 0, 1 }, 0.005f, { 0, 0 } });
    assert(near(ball.pos.y, 0.5f), "depth below SLOP must not be corrected");
    io::printfn("correction:   a.x=%.3f  b.x=%.3f", a.pos.x, b.pos.x);
    io::printn("impulse solver ok");
}
