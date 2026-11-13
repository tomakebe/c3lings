// =====================================================================
//  e2002 · Итоговый проект, шаг 2: ECS на разреженных множествах
// =====================================================================
//
//  Ядро из шага 1 уже на месте (core.c3 — это решение шага 1). Теперь
//  мир сущностей (ecs.c3, см. главу 05). Мы выбрали sparse set, а не
//  архетипы: проще, добавление/удаление компонента — O(1), а для
//  маленькой игры скорость итерации одинакова.
//
//      SparseSet{Velocity}:
//        sparse: [ 2  .  0  .  1 ]      индекс = сущность
//        dense:  [ 2  4  0 ]            кто лежит в data[i]
//        data:   [v2 v4 v0 ]            плотно, итерируем линейно
//
//      remove(4): последний (0) переезжает на место 4:
//        dense: [2 0], data: [v2 v0], sparse[0] = 1
//
//  Система — это просто цикл по самому «редкому» множеству и проверка
//  остальных компонентов через get():
//
//      for (uint i = 0; i < w.velocities.len; i++)
//      {
//          uint e = w.velocities.dense[i];
//          Transform* t = w.transforms.get(e);
//          if (!t) continue;
//          ...
//      }
//
//  ЗАДАЧА: в ecs.c3 реализуйте SparseSet.set, SparseSet.get и
//  SparseSet.remove. Посмотрите и на World.destroy_later/flush: почему
//  удаление отложено до конца тика?
//
module mini::app;
import mini::core, mini::ecs, std::io;

fn void movement_system(World* w)
{
    for (uint i = 0; i < w.velocities.len; i++)
    {
        uint e = w.velocities.dense[i];
        Transform* t = w.transforms.get(e);
        if (!t) continue;
        Velocity* v = &w.velocities.data[i];
        t.x += v.vx;
        t.y += v.vy;
    }
}

fn void lifetime_system(World* w)
{
    for (uint i = 0; i < w.lifetimes.len; i++)
    {
        Lifetime* l = &w.lifetimes.data[i];
        if (--l.ticks <= 0) w.destroy_later(w.lifetimes.dense[i]);
    }
}

fn void main()
{
    // --- SparseSet сам по себе
    SparseSet{int} s;
    s.set(5, 50);
    s.set(1, 10);
    s.set(7, 70);
    s.set(5, 55);                       // перезапись
    assert(s.len == 3 && *s.get(5) == 55);
    assert(s.get(2) == null, "нет компонента — null");
    s.remove(5);
    assert(s.len == 2 && !s.has(5) && *s.get(7) == 70 && *s.get(1) == 10, "swap-remove");
    s.remove(5);                        // повторно — без эффекта
    s.remove(7);
    s.remove(1);
    assert(s.len == 0);
    io::printn("sparse set: ok");

    // --- мир: пули с временем жизни
    World* w = mem::new(World);
    defer free(w);
    Rng rng = { 2024 };
    int spawned = 0;
    for (int tick = 0; tick < 60; tick++)
    {
        if (tick % 3 == 0)
        {
            Handle h = w.spawn();
            w.transforms.set(h.index, { rng.range(0, 64) * core::FX, rng.range(0, 24) * core::FX, 0 });
            w.velocities.set(h.index, { rng.range(-64, 64), rng.range(-64, 64) });
            w.lifetimes.set(h.index, { rng.range(5, 20) });
            w.tags.set(h.index, { BULLET, 0 });
            spawned++;
        }
        movement_system(w);
        lifetime_system(w);
        w.flush();
        assert(w.transforms.len == w.pool.live && w.lifetimes.len == w.pool.live, "все множества синхронны");
    }
    io::printfn("spawned=%d alive=%d", spawned, w.pool.live);
    io::printfn("world checksum=%08x", w.checksum());
}
