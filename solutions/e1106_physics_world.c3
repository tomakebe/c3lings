// =====================================================================
//  e1106 · Физический мир: фиксированный шаг, солвер, сон тел
// =====================================================================
//
//  Сначала прочитайте engine/docs/11_physics.md целиком — это
//  упражнение собирает всю главу.
//
//  Мы склеиваем куски из предыдущих упражнений в настоящий мир:
//
//    advance(frame_dt)            — вызывается раз в КАДР рендера
//      accumulator += frame_dt
//      while (accumulator >= DT && steps < MAX_SUBSTEPS): step()
//      если упёрлись в MAX_SUBSTEPS — выбрасываем остаток
//      («спираль смерти»: медленный кадр -> больше шагов -> ещё медленнее)
//      alpha = accumulator / DT   — для интерполяции рендера (глава 01)
//
//    step()                        — один шаг симуляции длиной DT
//      1. интеграция СКОРОСТЕЙ: v += g*dt, затухание     (полунеявный Эйлер)
//      2. сбор контактов: broadphase + narrowphase       (готово)
//      3. ITERATIONS проходов импульсного солвера по всем контактам
//         (последовательные импульсы, sequential impulses: каждый
//         контакт видит результат предыдущего — так стопка «договаривается»)
//      4. интеграция ПОЛОЖЕНИЙ по новым скоростям
//      5. позиционная коррекция
//      6. обновление сна
//
//  Сон (sleeping). Лежащее тело всё равно тратит время солвера и
//  «дрожит» от численного шума. Если |v| и |w| остаются ниже порога
//  SLEEP_TIME секунд подряд, тело засыпает: не интегрируется, а в
//  солвере ведёт себя как статическое (inv_mass = 0, см. inv_m()). Его
//  будит контакт с бодрствующим ДВИЖУЩИМСЯ телом. Настоящие движки
//  усыпляют целые острова (islands) связанных контактами тел — иначе
//  стопка засыпает «снизу», а верх продолжает давить; для нашего мира
//  хватит пообъектного сна.
//
//  Broadphase здесь — перебор пар (тел мало); в реальном мире сюда
//  подключается SAP или сетка из e1103. Импульсный солвер — из e1105
//  (уже реализован ниже, но с учётом сна).
//
//  ЗАДАЧА: реализуйте `World.advance`, `World.step` и
//  `World.update_sleep` (TODO). Всё остальное уже работает.
//
import std::io, std::math, std::collections::list;

alias Vec2 = float[<2>];

const double DT = 1.0 / 60.0;
const int MAX_SUBSTEPS = 4;
const int ITERATIONS = 8;
const Vec2 GRAVITY = { 0, -10 };
const float DAMPING = 0.5f;          // 1/с, линейное и угловое
const float SLOP = 0.01f;
const float PERCENT = 0.4f;
const float SLEEP_LINEAR = 0.05f;    // м/с
const float SLEEP_ANGULAR = 0.05f;   // рад/с
const float SLEEP_TIME = 0.5f;       // с
const float WORLD_W = 20;

struct Body
{
    Vec2 pos;
    Vec2 vel;
    float w;
    float radius;
    float inv_mass;
    float inv_inertia;
    float restitution;
    float friction;
    bool awake;
    float sleep_timer;
}

struct Contact
{
    int a;          // индекс тела или -1 для статического окружения
    int b;
    Vec2 normal;    // от A к B
    float depth;
    Vec2 point;
}

struct World
{
    List{Body} bodies;
    List{Contact} contacts;
    Body ground;    // статическое тело для пола и стен
    double accumulator;
    double alpha;
    long total_steps;
}

fn float cross(Vec2 a, Vec2 b) => a.x * b.y - a.y * b.x;
fn Vec2 cross_sv(float w, Vec2 r) => { -w * r.y, w * r.x };
fn float inv_m(Body* b) => b.awake ? b.inv_mass : 0;
fn float inv_i(Body* b) => b.awake ? b.inv_inertia : 0;

fn void World.free(&self)
{
    self.bodies.free();
    self.contacts.free();
}

fn void World.add_ball(&self, Vec2 pos, Vec2 vel, float radius, float e)
{
    float mass = (float)math::PI * radius * radius;
    float inertia = 0.5f * mass * radius * radius;
    self.bodies.push({ .pos = pos, .vel = vel, .radius = radius, .inv_mass = 1 / mass,
                       .inv_inertia = 1 / inertia, .restitution = e, .friction = 0.6f, .awake = true });
}

fn Body* World.body(&self, int i) => i < 0 ? &self.ground : &self.bodies[i];

// ------------------------------------------------------------------ готово: коллизии
fn void World.collect_contacts(&self)
{
    self.contacts.clear();
    sz count = self.bodies.len();
    for (int i = 0; i < count; i++)
    {
        Body* b = &self.bodies[i];
        // Пол (y = 0) и стены (x = 0, x = WORLD_W) — полуплоскости.
        if (b.pos.y - b.radius < 0)
        {
            self.contacts.push({ -1, i, { 0, 1 }, b.radius - b.pos.y, b.pos - (Vec2){ 0, b.radius } });
        }
        if (b.pos.x - b.radius < 0)
        {
            self.contacts.push({ -1, i, { 1, 0 }, b.radius - b.pos.x, b.pos - (Vec2){ b.radius, 0 } });
        }
        if (b.pos.x + b.radius > WORLD_W)
        {
            self.contacts.push({ -1, i, { -1, 0 }, b.pos.x + b.radius - WORLD_W, b.pos + (Vec2){ b.radius, 0 } });
        }
        // Пары шаров (broadphase = перебор).
        for (int j = i + 1; j < count; j++)
        {
            Body* o = &self.bodies[j];
            if (!b.awake && !o.awake) continue;
            Vec2 d = o.pos - b.pos;
            float rs = b.radius + o.radius;
            float dist2 = d.dot(d);
            if (dist2 >= rs * rs || dist2 == 0) continue;
            float dist = math::sqrt(dist2);
            Vec2 n = d / dist;
            self.contacts.push({ i, j, n, rs - dist, b.pos + n * b.radius });
        }
    }
}

// ------------------------------------------------------------------ готово: солвер (e1105 + сон)
fn void apply_impulse(Body* b, Vec2 impulse, Vec2 r)
{
    b.vel += impulse * inv_m(b);
    b.w += inv_i(b) * cross(r, impulse);
}

fn void resolve_contact(Body* a, Body* b, Contact* c)
{
    Vec2 n = c.normal;
    Vec2 ra = c.point - a.pos;
    Vec2 rb = c.point - b.pos;
    Vec2 vr = (b.vel + cross_sv(b.w, rb)) - (a.vel + cross_sv(a.w, ra));
    float vn = vr.dot(n);
    if (vn > 0) return;
    float ran = cross(ra, n);
    float rbn = cross(rb, n);
    float k = inv_m(a) + inv_m(b) + ran * ran * inv_i(a) + rbn * rbn * inv_i(b);
    if (k == 0) return;
    // Маленькие скорости удара не отражаем — иначе тело вечно «подпрыгивает».
    float e = vn < -1.0f ? math::min(a.restitution, b.restitution) : 0.0f;
    float j = -(1 + e) * vn / k;
    apply_impulse(a, -n * j, ra);
    apply_impulse(b, n * j, rb);

    vr = (b.vel + cross_sv(b.w, rb)) - (a.vel + cross_sv(a.w, ra));
    Vec2 t = vr - n * vr.dot(n);
    float tl = t.length();
    if (tl < 1e-6f) return;
    t /= tl;
    float rat = cross(ra, t);
    float rbt = cross(rb, t);
    float kt = inv_m(a) + inv_m(b) + rat * rat * inv_i(a) + rbt * rbt * inv_i(b);
    float mu = math::sqrt(a.friction * b.friction);
    float jt = math::clamp(-vr.dot(t) / kt, -mu * j, mu * j);
    apply_impulse(a, -t * jt, ra);
    apply_impulse(b, t * jt, rb);
}

fn void positional_correction(Body* a, Body* b, Contact* c)
{
    float inv_sum = inv_m(a) + inv_m(b);
    if (inv_sum == 0) return;
    float corr = math::max(c.depth - SLOP, 0.0f) / inv_sum * PERCENT;
    a.pos -= c.normal * (corr * inv_m(a));
    b.pos += c.normal * (corr * inv_m(b));
}

// ------------------------------------------------------------------ сон
// Будит спящее тело, если его касается бодрствующее и движущееся.
fn void World.wake_touched(&self)
{
    foreach (&c : self.contacts)
    {
        if (c.a < 0) continue;
        Body* a = self.body(c.a);
        Body* b = self.body(c.b);
        if (a.awake == b.awake) continue;
        Body* mover = a.awake ? a : b;
        Body* sleeper = a.awake ? b : a;
        if (mover.vel.length() > SLEEP_LINEAR)
        {
            sleeper.awake = true;
            sleeper.sleep_timer = 0;
        }
    }
}

// ------------------------------------------------------------------ TODO
fn void World.update_sleep(&self, float dt)
{
    foreach (&b : self.bodies)
    {
        if (!b.awake) continue;
        if (b.vel.length() < SLEEP_LINEAR && math::abs(b.w) < SLEEP_ANGULAR)
        {
            b.sleep_timer += dt;
            if (b.sleep_timer >= SLEEP_TIME)
            {
                b.awake = false;
                b.vel = { 0, 0 };
                b.w = 0;
            }
        }
        else
        {
            b.sleep_timer = 0;
        }
    }
}

fn void World.step(&self)
{
    float dt = (float)DT;
    // 1. Скорости.
    foreach (&b : self.bodies)
    {
        if (!b.awake) continue;
        b.vel += GRAVITY * dt;
        float damp = 1.0f / (1.0f + dt * DAMPING);
        b.vel *= damp;
        b.w *= damp;
    }
    // 2. Контакты.
    self.collect_contacts();
    self.wake_touched();
    // 3. Солвер.
    for (int it = 0; it < ITERATIONS; it++)
    {
        foreach (&c : self.contacts) resolve_contact(self.body(c.a), self.body(c.b), c);
    }
    // 4. Положения.
    foreach (&b : self.bodies)
    {
        if (b.awake) b.pos += b.vel * dt;
    }
    // 5. Коррекция.
    foreach (&c : self.contacts) positional_correction(self.body(c.a), self.body(c.b), c);
    // 6. Сон.
    self.update_sleep(dt);
    self.total_steps++;
}

// Возвращает число выполненных шагов.
fn int World.advance(&self, double frame_dt)
{
    self.accumulator += frame_dt;
    int steps = 0;
    while (self.accumulator >= DT && steps < MAX_SUBSTEPS)
    {
        self.step();
        self.accumulator -= DT;
        steps++;
    }
    if (self.accumulator >= DT) self.accumulator = 0;   // спираль смерти: отбрасываем долг
    self.alpha = self.accumulator / DT;
    return steps;
}

// ------------------------------------------------------------------ проверка
fn void main()
{
    World world;
    defer world.free();
    world.ground = { .friction = 0.6f };            // inv_mass = 0, awake = false -> статическое

    world.add_ball({ 2, 5 }, { 0, 0 }, 0.5f, 0.5f);     // 0: прыгает и успокаивается
    world.add_ball({ 4, 1 }, { -2, 0 }, 0.5f, 0.2f);    // 1: катится в левую стену
    world.add_ball({ 8, 0.5f }, { 0, 0 }, 0.5f, 0.0f);  // 2-4: стопка из трёх
    world.add_ball({ 8, 1.6f }, { 0, 0 }, 0.5f, 0.0f);
    world.add_ball({ 8, 2.7f }, { 0, 0 }, 0.5f, 0.0f);
    world.add_ball({ 12, 1 }, { 5, 0 }, 0.5f, 0.3f);    // 5: катится вправо...
    world.add_ball({ 17, 0.5f }, { 0, 0 }, 0.5f, 0.3f); // 6: ...и будит спящего соседа

    // Фиксированный шаг: разные длины кадров.
    int s1 = world.advance(1.0 / 60.0);
    int s2 = world.advance(1.0 / 30.0);
    int s3 = world.advance(1.0 / 40.0);
    double a3 = world.alpha;
    int s4 = world.advance(0.5);                        // «подвисание» на полсекунды
    assert(s1 == 1 && s2 == 2 && s3 == 1, "accumulator: got %d %d %d steps", s1, s2, s3);
    assert(math::abs(a3 - 0.5) < 1e-6, "alpha must be accumulator / DT");
    assert(s4 == MAX_SUBSTEPS && world.accumulator == 0, "spiral of death: clamp to MAX_SUBSTEPS and drop the rest");
    io::printfn("steps per frame: %d %d %d (alpha %.2f) then %d after a hitch", s1, s2, s3, a3, s4);

    // Через ~0.6 с шестое тело уже должно уснуть, а пятое ещё катится к нему.
    for (int f = 0; f < 30; f++) world.advance(1.0 / 60.0);
    assert(!world.bodies[6].awake, "a resting body must fall asleep after SLEEP_TIME");
    assert(world.bodies[5].awake, "body 5 is moving and must stay awake");
    io::printn("body 6 fell asleep while body 5 is still rolling");

    bool woke = false;
    for (int f = 0; f < 20 * 60; f++)
    {
        world.advance(1.0 / 60.0);
        if (world.bodies[6].awake) woke = true;
    }
    assert(woke, "body 5 must wake body 6 on contact");
    io::printfn("body 6 was woken up by body 5; simulated %d steps", world.total_steps);

    foreach (i, &b : world.bodies)
    {
        assert(!b.awake, "body %d must be asleep after 20 s", i);
        assert(b.pos.x >= 0.45f && b.pos.x <= WORLD_W - 0.45f, "body %d left the world", i);
        io::printfn("body %d: asleep, y=%.1f", i, b.pos.y);
    }
    // Стопка стоит: тела друг над другом, проникновения малы.
    for (int i = 2; i <= 4; i++)
    {
        Body* b = &world.bodies[i];
        assert(math::abs(b.pos.x - 8) < 1e-3f, "stack drifted sideways");
        assert(math::abs(b.pos.y - (0.5f + (float)(i - 2))) < 0.08f, "stack body %d sank: y=%f", i, b.pos.y);
    }
    io::printn("stack holds; world is at rest");
}
