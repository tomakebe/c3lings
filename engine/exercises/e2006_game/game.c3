// ---------------------------------------------------------------------
//  mini::game — игра в духе Asteroids поверх мини-движка.
//
//  Всё, что относится к ПРАВИЛАМ игры, живёт здесь; движок (core, ecs,
//  physics, render, ...) о кораблях и астероидах ничего не знает.
//  Это и есть граница «движок / игра».
// ---------------------------------------------------------------------
module mini::game;
import mini::core, mini::ecs, mini::events, mini::physics, mini::input, mini::render, mini::profile;

const uint L_SHIP = 1;
const uint L_BULLET = 2;
const uint L_ROCK = 4;

const int FIRE_COOLDOWN = 8;
const int BULLET_LIFE = 25;
const int RESPAWN_TICKS = 60;

struct Game
{
    World* w;
    Arena* arena;
    Profiler* prof;
    Rng rng;
    InputState input;
    EventQueue q;
    Handle ship;
    bool has_ship;
    int respawn_timer;
    int lives;
    int score;
    int wave;
    int cooldown;
    int tick;
    int shots;
    int rocks_destroyed;
}

fn void Game.init(&self, World* w, Arena* arena, Profiler* prof, uint seed)
{
    *self = { .w = w, .arena = arena, .prof = prof, .rng = { seed }, .lives = 3 };
    self.spawn_ship();
    self.spawn_wave();
}

fn void Game.spawn_ship(&self)
{
    Handle h = self.w.spawn();
    uint e = h.index;
    self.w.transforms.set(e, { physics::WORLD_W / 2, physics::WORLD_H / 2, 24 });
    self.w.velocities.set(e, { 0, 0 });
    self.w.colliders.set(e, { core::FX, L_SHIP, L_ROCK });
    self.w.sprites.set(e, { 'A', 0 });
    self.w.tags.set(e, { SHIP, 0 });
    self.ship = h;
    self.has_ship = true;
}

fn void Game.spawn_rock(&self, int x, int y, int vx, int vy, int size)
{
    Handle h = self.w.spawn();
    uint e = h.index;
    self.w.transforms.set(e, { x, y, 0 });
    self.w.velocities.set(e, { vx, vy });
    self.w.colliders.set(e, { size * core::FX, L_ROCK, 0 });
    self.w.sprites.set(e, { size == 3 ? 'O' : (size == 2 ? 'o' : '+'), size });
    self.w.tags.set(e, { ASTEROID, size });
}

fn void Game.spawn_wave(&self)
{
    self.wave++;
    for (int i = 0; i < 2 + self.wave; i++)
    {
        int x = self.rng.range(0, 63) * core::FX;
        int y = (i % 2 == 0 ? self.rng.range(0, 4) : self.rng.range(19, 23)) * core::FX;
        int vx = self.rng.range(10, 40) * (self.rng.next() % 2 == 0 ? 1 : -1);
        int vy = self.rng.range(5, 20) * (self.rng.next() % 2 == 0 ? 1 : -1);
        self.spawn_rock(x, y, vx, vy, 3);
    }
}

fn void Game.fire(&self, Transform* t, Velocity* v)
{
    int[2] d = render::DIRS[t.angle & 31];
    Handle h = self.w.spawn();
    uint e = h.index;
    self.w.transforms.set(e, { t.x + d[0] * 2, t.y + d[1] * 2, t.angle });
    self.w.velocities.set(e, { v.vx + d[0] * 3 / 2, v.vy + d[1] * 3 / 2 });
    self.w.colliders.set(e, { core::FX / 2, L_BULLET, L_ROCK });
    self.w.sprites.set(e, { '.', 0 });
    self.w.lifetimes.set(e, { BULLET_LIFE });
    self.w.tags.set(e, { BULLET, 0 });
    self.shots++;
}

fn void Game.control_ship(&self)
{
    if (!self.has_ship)
    {
        if (self.lives > 0 && --self.respawn_timer <= 0) self.spawn_ship();
        return;
    }
    uint e = self.ship.index;
    Transform* t = self.w.transforms.get(e);
    Velocity* v = self.w.velocities.get(e);
    if (self.input.down(LEFT)) t.angle = (t.angle + 31) & 31;
    if (self.input.down(RIGHT)) t.angle = (t.angle + 1) & 31;
    if (self.input.down(THRUST))
    {
        int[2] d = render::DIRS[t.angle];
        v.vx += d[0] / 16;
        v.vy += d[1] / 16;
    }
    v.vx -= v.vx / 32;      // «трение» — чтобы корабль был управляемым
    v.vy -= v.vy / 32;
    if (self.cooldown > 0) self.cooldown--;
    if (self.input.down(FIRE) && self.cooldown == 0)
    {
        self.fire(t, v);
        self.cooldown = FIRE_COOLDOWN;
    }
}

<*
 Астероид e размера size разваливается на два размера size - 1 (если
 size > 1) в той же точке. Скорости осколков — скорость родителя,
 повёрнутая на +90 и -90 градусов и умноженная на 5/4:
     (-vy, vx) * 5 / 4   и   (vy, -vx) * 5 / 4
 Сначала осколок с (-vy, vx), затем с (vy, -vx) — порядок важен для
 детерминизма контрольной суммы.
*>
fn void Game.split_rock(&self, uint e, int size)
{
    // TODO
    (void)e;
    (void)size;
}

<*
 Обработать одно событие столкновения:
   * если любая из сущностей уже обречена (w.is_doomed) — пропустить;
   * ПУЛЯ + АСТЕРОИД: обе сущности — destroy_later; очки
     score += (4 - size) * 10; rocks_destroyed++; split_rock(астероид);
   * КОРАБЛЬ + АСТЕРОИД: корабль — destroy_later, has_ship = false,
     lives--, respawn_timer = RESPAWN_TICKS. Астероид не трогаем.
 Порядок a/b в событии произвольный — учтите оба варианта.
*>
fn void Game.on_collision(&self, CollisionEvent ev)
{
    // TODO
    (void)ev;
}

fn int Game.rock_count(&self)
{
    int n = 0;
    for (uint i = 0; i < self.w.tags.len; i++)
    {
        if (self.w.tags.data[i].kind == ASTEROID && !self.w.is_doomed(self.w.tags.dense[i])) n++;
    }
    return n;
}

fn void Game.update(&self, char bits)
{
    self.tick++;
    self.input.update(bits);
    profile::@zone(self.prof, "ship")
    {
        self.control_ship();
    };
    profile::@zone(self.prof, "lifetime")
    {
        for (uint i = 0; i < self.w.lifetimes.len; i++)
        {
            Lifetime* l = &self.w.lifetimes.data[i];
            if (--l.ticks <= 0) self.w.destroy_later(self.w.lifetimes.dense[i]);
        }
        self.prof.add_work(self.w.lifetimes.len);
    };
    profile::@zone(self.prof, "physics")
    {
        self.prof.add_work(physics::integrate(self.w));
        Grid* grid = self.arena.alloc(Grid::size, Grid::alignment);
        assert(grid != null, "кадровая арена переполнена");
        grid.build(self.w);
        profile::@zone(self.prof, "narrowphase")
        {
            self.prof.add_work(physics::detect_collisions(self.w, grid, &self.q));
        };
    };
    self.q.swap();
    profile::@zone(self.prof, "rules")
    {
        foreach (ev : self.q.read()) self.on_collision(ev);
        self.prof.add_work(self.q.read().len);
    };
    self.w.flush();
    // TODO: все астероиды уничтожены — следующая волна
}
