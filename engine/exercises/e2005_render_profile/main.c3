// =====================================================================
//  e2005 · Итоговый проект, шаг 5: рендер в кадровый буфер и профайлер
// =====================================================================
//
//  Добавились render.c3 (глава 09) и profile.c3 (глава 15).
//
//  Брезенхем: ошибка err накапливает, насколько линия ушла от идеальной;
//  на каждом шаге решаем, сдвинуться ли по x, по y или по обоим:
//
//      dx = |x1-x0|, dy = -|y1-y0|, err = dx + dy
//      цикл: put(x0,y0); если пришли — выход
//            e2 = 2*err
//            если e2 >= dy: err += dy, x0 += sx
//            если e2 <= dx: err += dx, y0 += sy
//
//  Окружность (средняя точка): идём по октанту от (r, 0), пока x >= y,
//  и отражаем точку в 8 октантов. err = 1 - r; если err < 0 — только
//  y++, иначе y++ и x--.
//
//  Профайлер: зоны вкладываются, работа приписывается самой внутренней.
//
//  ЗАДАЧА: реализуйте Framebuffer.line и Framebuffer.circle (render.c3),
//  Profiler.begin, end и add_work (profile.c3).
//
module mini::app;
import mini::core, mini::ecs, mini::render, mini::profile, std::io;

fn void main()
{
    Framebuffer fb;
    fb.clear('.');

    // линии во всех октантах — «звезда»
    for (int k = 0; k < 16; k++)
    {
        int[2] d = render::DIRS[k * 2];
        fb.line(12, 12, 12 + d[0] * 10 / 256, 12 + d[1] * 10 / 256, '#');
    }
    assert(fb.at(22, 12) == '#' && fb.at(2, 12) == '#' && fb.at(12, 2) == '#', "концы осевых линий");
    assert(fb.at(17, 12) == '#' && fb.at(12, 17) == '#', "середины осевых линий");
    fb.line(30, 2, 60, 9, '\\');
    fb.line(60, 9, 30, 2, '\\');          // в обратную сторону — те же пиксели
    assert(fb.at(45, 5) == '\\' || fb.at(45, 6) == '\\');

    fb.circle(45, 15, 7, 'o');
    fb.circle(45, 15, 3, 'O');
    fb.circle(62, 22, 5, '@');            // частично за краем — отсечение
    assert(fb.at(52, 15) == 'o' && fb.at(45, 8) == 'o' && fb.at(38, 15) == 'o' && fb.at(45, 22) == 'o');
    assert(fb.at(45, 15) == '.', "окружность, а не круг");
    fb.print();
    io::printfn("framebuffer checksum=%08x", fb.checksum());

    // --- профайлер
    Profiler prof;
    for (int frame = 0; frame < 3; frame++)
    {
        profile::@zone(&prof, "frame")
        {
            profile::@zone(&prof, "update")
            {
                profile::@zone(&prof, "physics") { prof.add_work((long)(100 + frame)); };
                profile::@zone(&prof, "game") { prof.add_work(7); };
            };
            profile::@zone(&prof, "render") { prof.add_work(1536); };
            prof.add_work(1);
        };
    }
    assert(prof.depth == 0, "все зоны закрыты");
    assert(prof.zones[0].calls == 3 && prof.zones[0].work == 3, "работа — во внутреннюю зону");
    assert(prof.zones[2].depth == 2 && prof.zones[2].work == 303);
    prof.report();
}
