// =====================================================================
//  106 · Data-oriented design: AoS -> SoA
// =====================================================================
//
//  Добро пожаловать в Часть IV. Дальше упражнения большие: вы будете
//  реализовывать настоящие структуры данных и подсистемы, а main()
//  проверяет вашу работу десятками assert'ов.
//
//  ПРОБЛЕМА
//  --------
//  Процессор читает память не байтами, а кеш-линиями (обычно 64 байта).
//  Промах мимо L1/L2 стоит десятки-сотни тактов, а арифметика над float
//  — один-два. Поэтому в «горячих» циклах (физика частиц, трансформации,
//  culling) узкое место почти всегда — пропускная способность памяти,
//  а не вычисления.
//
//  Классический ООП-стиль — «массив структур» (Array of Structures, AoS):
//
//      struct Particle { float x, y, vx, vy, mass, life; uint color; char[36] name; }
//      Particle[N] ps;               // [x y vx vy mass life color name...][x y ...]
//
//  Цикл интеграции читает только x, y, vx, vy — 16 байт из 64. Значит,
//  3/4 каждой загруженной кеш-линии — мусор, который мы тащим из памяти
//  зря. Плюс поля одного типа лежат не подряд, и компилятору трудно
//  векторизовать цикл (нужны gather/scatter вместо плотной загрузки).
//
//  РЕШЕНИЕ: «структура массивов» (Structure of Arrays, SoA):
//
//      x:  [x0 x1 x2 x3 ...]
//      y:  [y0 y1 y2 y3 ...]
//      vx: [...]   vy: [...]   mass: [...]   ...
//
//  Теперь цикл по x/y/vx/vy читает 4 плотных потока, каждый байт кеш-линии
//  полезен, а `x[i] += vx[i] * dt` для 8 соседних i — ровно одна
//  AVX-инструкция. Холодные данные (name, color) вообще не трогаются.
//
//  ПРОСТРАНСТВО РЕШЕНИЙ И КОМПРОМИССЫ
//  ----------------------------------
//  * AoS удобнее, когда объект обрабатывается целиком (сериализация,
//    редактор, случайный доступ «дай мне частицу №17»).
//  * SoA выигрывает в потоковых проходах по нескольким полям.
//  * AoSoA («массив маленьких SoA-блоков», напр. по 8 элементов) —
//    компромисс: SIMD-дружественно и локально. Так устроены ISPC и многие
//    физические движки.
//  * Hot/cold splitting: горячие поля в одной структуре, холодные —
//    в параллельном массиве. Это «SoA по группам полей», чем пользуется
//    большинство ECS (Unity DOTS chunks, flecs, bevy table storage).
//
//  ПОДВОДНЫЕ КАМНИ SoA
//  -------------------
//  * Инвариант «все массивы одной длины и i-й элемент во всех массивах —
//    это одна сущность». Любая операция, меняющая порядок (удаление,
//    сортировка), обязана двигать ВСЕ массивы синхронно. Забыли один —
//    получили тихую порчу данных: у частицы чужой цвет.
//  * Удаление из середины: сдвиг O(n) дорог, поэтому в движках делают
//    swap-remove: последний элемент переносится на место удалённого.
//    Порядок не сохраняется — зато O(1). Внимание: после swap на позицию
//    i пришёл НЕпроверенный элемент, индекс i увеличивать нельзя.
//  * Указатель/индекс на элемент после swap-remove становится неверным —
//    отсюда handles/slot map (упражнение 110).
//  * Много мелких аллокаций. Серьёзные реализации выделяют ОДИН блок и
//    нарезают из него срезы; мы для простоты выделяем каждый массив
//    отдельно (init/free уже написаны).
//
//  В C3 срезы (`float[]`) — это пара (указатель, длина), так что SoA
//  выглядит естественно: `self.x[i]`. Проверки границ в safe-режиме
//  поймают ошибку индексации.
//
//  ЗАДАЧА: реализуйте методы ParticlesSoA, помеченные TODO:
//    * push      — разложить Particle по массивам (холодное имя не храним);
//    * get       — собрать Particle обратно (name оставить пустым);
//    * integrate — v.y += g*dt; x += vx*dt; y += vy*dt  (ровно в таком
//                  порядке операций, как в AoS-версии, чтобы float'ы
//                  совпали побитово!);
//    * tick_life — life -= dt; частицы с life <= 0 удалить swap-remove'ом.
//  Эталонная AoS-реализация дана — повторите её семантику.
//  main() гоняет обе версии параллельно и сравнивает результат.
//
import std::io;

struct Particle
{
    float x, y;
    float vx, vy;
    float mass;
    float life;
    uint  color;
    char[36] name;      // холодные данные: нужны только редактору
}

// ---------------------------------------------------------------- AoS (эталон)

fn void aos_integrate(Particle[] ps, float dt, float g)
{
    foreach (&p : ps)
    {
        p.vy += g * dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
    }
}

// Возвращает новую длину.
fn sz aos_tick_life(Particle[] ps, float dt)
{
    sz len = ps.len;
    sz i = 0;
    while (i < len)
    {
        ps[i].life -= dt;
        if (ps[i].life <= 0)
        {
            ps[i] = ps[len - 1];
            len--;
            continue;          // на место i пришёл новый элемент — проверить его тоже
        }
        i++;
    }
    return len;
}

// ---------------------------------------------------------------- SoA

struct ParticlesSoA
{
    sz len;
    sz cap;
    float[] x, y, vx, vy, mass, life;
    uint[] color;
}

fn void ParticlesSoA.init(&self, sz cap)
{
    *self = { .cap = cap };
    self.x = mem::new_array(float, cap);
    self.y = mem::new_array(float, cap);
    self.vx = mem::new_array(float, cap);
    self.vy = mem::new_array(float, cap);
    self.mass = mem::new_array(float, cap);
    self.life = mem::new_array(float, cap);
    self.color = mem::new_array(uint, cap);
}

fn void ParticlesSoA.free(&self)
{
    free(self.x); free(self.y); free(self.vx); free(self.vy);
    free(self.mass); free(self.life); free(self.color);
    *self = {};
}

fn void ParticlesSoA.push(&self, Particle p)
{
    assert(self.len < self.cap);
    // TODO: записать поля p в i-ю позицию каждого массива и увеличить len.
    sz i = self.len++;
    self.x[i] = p.x;
    self.y[i] = p.y;
    self.vx[i] = p.vx;
    self.vy[i] = p.vy;
    self.mass[i] = p.mass;
    self.life[i] = p.life;
    self.color[i] = p.color;
}

fn Particle ParticlesSoA.get(&self, sz i)
{
    // TODO: собрать Particle из i-х элементов массивов (name не заполняем).
    return {
        .x = self.x[i], .y = self.y[i],
        .vx = self.vx[i], .vy = self.vy[i],
        .mass = self.mass[i], .life = self.life[i],
        .color = self.color[i],
    };
}

fn void ParticlesSoA.integrate(&self, float dt, float g)
{
    // TODO: горячий цикл. Трогайте только x, y, vx, vy.
    //       Порядок операций — как в aos_integrate.
    sz n = self.len;
    float[] x = self.x[:n];
    float[] y = self.y[:n];
    float[] vx = self.vx[:n];
    float[] vy = self.vy[:n];
    for (sz i = 0; i < n; i++)
    {
        vy[i] += g * dt;
        x[i] += vx[i] * dt;
        y[i] += vy[i] * dt;
    }
}

// Удалить i-й элемент swap-remove'ом: последний переезжает на место i.
// Должна двигать ВСЕ массивы.
fn void ParticlesSoA.swap_remove(&self, sz i)
{
    // TODO
    sz last = self.len - 1;
    self.x[i] = self.x[last];
    self.y[i] = self.y[last];
    self.vx[i] = self.vx[last];
    self.vy[i] = self.vy[last];
    self.mass[i] = self.mass[last];
    self.life[i] = self.life[last];
    self.color[i] = self.color[last];
    self.len = last;
}

fn void ParticlesSoA.tick_life(&self, float dt)
{
    // TODO: как aos_tick_life, но через swap_remove.
    sz i = 0;
    while (i < self.len)
    {
        self.life[i] -= dt;
        if (self.life[i] <= 0)
        {
            self.swap_remove(i);
            continue;
        }
        i++;
    }
}

// ---------------------------------------------------------------- проверка

// Детерминированный генератор: значения кратны 1/8, поэтому float'ы точны.
uint seed = 12345;
fn uint next_rand()
{
    seed = seed * 1103515245 + 12345;
    return (seed >> 16) & 0x7FFF;
}
fn float rand_q(int range) => (float)((int)(next_rand() % (uint)(range * 8)) - range * 4) / 8.0f;

fn bool same(Particle a, Particle b)
{
    return a.x == b.x && a.y == b.y && a.vx == b.vx && a.vy == b.vy
        && a.mass == b.mass && a.life == b.life && a.color == b.color;
}

const sz N = 1000;

fn void main()
{
    Particle[] aos = mem::new_array(Particle, N);
    defer free(aos);
    ParticlesSoA soa;
    soa.init(N);
    defer soa.free();

    for (sz i = 0; i < N; i++)
    {
        Particle p = {
            .x = rand_q(100), .y = rand_q(100),
            .vx = rand_q(10), .vy = rand_q(10),
            .mass = 1.0f + (float)(i % 4),
            .life = 0.5f + (float)(next_rand() % 40) * 0.25f,
            .color = 0xFF000000 | (uint)i,
        };
        aos[i] = p;
        soa.push(p);
    }
    assert(soa.len == N, "push: wrong length");
    assert(same(soa.get(0), aos[0]) && same(soa.get(N - 1), aos[N - 1]), "push/get mismatch");

    // Маленький тест swap_remove: все массивы должны сдвигаться синхронно.
    {
        ParticlesSoA t;
        t.init(3);
        defer t.free();
        t.push({ .x = 1, .color = 1 });
        t.push({ .x = 2, .color = 2 });
        t.push({ .x = 3, .color = 3 });
        t.swap_remove(0);
        assert(t.len == 2, "swap_remove: len");
        assert(t.x[0] == 3 && t.color[0] == 3, "swap_remove: some array was not moved");
        assert(t.x[1] == 2 && t.color[1] == 2, "swap_remove: order");
    }

    sz aos_len = N;
    float dt = 0.25f;
    for (int step = 0; step < 16; step++)
    {
        aos_integrate(aos[:aos_len], dt, -9.75f);
        aos_len = aos_tick_life(aos[:aos_len], dt);
        soa.integrate(dt, -9.75f);
        soa.tick_life(dt);
        assert(soa.len == aos_len, "step %d: alive count differs (%d vs %d)", step, soa.len, aos_len);
        for (sz i = 0; i < aos_len; i++)
        {
            assert(same(soa.get(i), aos[i]), "step %d: particle %d differs", step, i);
        }
    }

    double sum_x = 0;
    double sum_y = 0;
    for (sz i = 0; i < soa.len; i++)
    {
        sum_x += soa.x[i];
        sum_y += soa.y[i];
    }
    io::printfn("alive after 16 steps: %d of %d", soa.len, N);
    io::printfn("sum x = %.3f, sum y = %.3f", sum_x, sum_y);
    io::printfn("AoS: integrate loads %d bytes per particle, uses 16", Particle::size);
    io::printfn("SoA: integrate loads 16 bytes per particle, uses 16");
    io::printn("SoA matches AoS bit-for-bit");
}
