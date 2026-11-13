// =====================================================================
//  123 · Дизайн API: opaque-хендлы, builder, модули
// =====================================================================
//
//  Это упражнение из двух файлов: `gfx.c3` — «библиотека» (модуль gfx),
//  `main.c3` — её пользователь. Править нужно gfx.c3; этот файл
//  показывает, каким API должен быть СНАРУЖИ.
//
//  ЧТО ДЕЛАЕТ API ХОРОШИМ
//  ----------------------
//  Внутренности подсистемы (рендер, аудио, физика) меняются постоянно,
//  а её API используют сотни мест. Хороший API:
//  * прячет представление (можно переписать хранилище, не трогая
//    пользователей);
//  * делает неправильное использование трудным или невозможным;
//  * дешёв в типичном случае и явен в сложном.
//
//  1. OPAQUE-ХЕНДЛЫ ВМЕСТО УКАЗАТЕЛЕЙ
//     Пользователь получает `TextureId` — число, а не `Texture*`. Он не
//     может залезть в поля, не может освободить чужую память, а
//     библиотека может перемещать данные, хранить их на GPU, в пуле и
//     т.д. В id упаковано поколение (как в slot map из 110): «протухший»
//     id после destroy распознаётся, а не превращается в use-after-free.
//     `typedef TextureId = uint;` — отдельный тип: нельзя перепутать с
//     MeshId или передать случайное число без явного приведения.
//     Так сделаны sokol_gfx (sg_image), bgfx (TextureHandle), Vulkan
//     (VkImage — тоже непрозрачный хендл), файловые дескрипторы POSIX.
//
//  2. ВИДИМОСТЬ МОДУЛЯ
//     Всё, что пользователю знать не нужно, помечается `@private`:
//     структура записи, глобальный пул, вспомогательные функции. Из
//     main.c3 они просто не видны — компилятор не даст на них
//     сослаться. (`@local` — ещё строже: только этот файл.)
//
//  3. BUILDER ДЛЯ СЛОЖНЫХ ОПИСАНИЙ
//     У текстуры десяток параметров, большинство — по умолчанию.
//     Варианты: функция с 10 аргументами (нечитаемо: `create(256, 256,
//     1, true, false, 3)` — что тут что?), структура-описание с
//     designated-инициализатором (хороший C-стиль: `{ .width = 256 }`)
//     или builder с цепочкой вызовов:
//         gfx::texture("albedo").size(256, 256).format(RGBA8).mipmaps().build()
//     В C3 builder удобно делать ПО ЗНАЧЕНИЮ: каждый метод принимает
//     `self` копией, меняет поле и возвращает её. Цепочка работает на
//     временных значениях, не нужны аллокации и указатели. Валидация
//     собрана в одном месте — в build(), который возвращает Optional.
//
//  4. ИМЕНОВАННЫЕ АРГУМЕНТЫ С УМОЛЧАНИЯМИ
//     Для простых случаев C3 даёт `fn ... create_solid(String name, int
//     w, int h, Format format = RGBA8, bool mipmaps = false)` и вызов
//     `create_solid("x", 4, 4, mipmaps: true)` — самодокументируемо.
//
//  5. ОШИБКИ КАК ЧАСТЬ API: build() не падает, а возвращает
//     INVALID_SIZE / MIPMAPS_NEED_POW2 / OUT_OF_SLOTS; доступ по
//     протухшему хендлу — STALE_HANDLE.
//
//  ЗАДАЧА (в gfx.c3): допишите методы builder'а, build() с валидацией,
//  упаковку/распаковку TextureId и lookup с проверкой поколения.
//
module main;
import std::io;
import gfx;

fn void main()
{
    gfx::TextureId albedo = gfx::texture("albedo").size(256, 256).format(RGBA8).mipmaps().build()!!;
    gfx::TextureId mask = gfx::texture("mask").size(100, 60).format(R8).build()!!;
    gfx::TextureId solid = gfx::create_solid("white", 4, 4, mipmaps: true)!!;

    io::printfn("%s: %dx%d, %d mips, %d bytes", gfx::name(albedo)!!, gfx::width(albedo)!!, gfx::height(albedo)!!,
                gfx::mip_count(albedo)!!, gfx::memory_bytes(albedo)!!);
    io::printfn("%s: %dx%d, %d mips, %d bytes", gfx::name(mask)!!, gfx::width(mask)!!, gfx::height(mask)!!,
                gfx::mip_count(mask)!!, gfx::memory_bytes(mask)!!);
    assert(gfx::memory_bytes(solid)!! == (16 + 4 + 1) * 4);
    assert(gfx::mip_count(albedo)!! == 9 && gfx::memory_bytes(albedo)!! == 349524);

    // валидация в build()
    assert(@catch(gfx::texture("empty").build()) == gfx::INVALID_SIZE, "zero size must be rejected");
    assert(@catch(gfx::texture("odd").size(100, 60).mipmaps().build()) == gfx::MIPMAPS_NEED_POW2);
    assert(@catch(gfx::texture("huge").size(1 << 15, 4).build()) == gfx::INVALID_SIZE);

    // билдер — значение: базовое описание можно переиспользовать
    gfx::TextureBuilder base = gfx::texture("shadow").format(DEPTH32);
    gfx::TextureId s1 = base.size(1024, 1024).build()!!;
    gfx::TextureId s2 = base.size(512, 512).label("shadow_lo").build()!!;
    assert(gfx::width(s1)!! == 1024 && gfx::width(s2)!! == 512 && gfx::name(s2)!! == "shadow_lo");
    assert(gfx::name(s1)!! == "shadow");

    // хендлы: протухание и переиспользование слота
    gfx::destroy(mask)!!;
    assert(@catch(gfx::width(mask)) == gfx::STALE_HANDLE, "destroyed handle must be stale");
    assert(@catch(gfx::destroy(mask)) == gfx::STALE_HANDLE, "double destroy must fail");
    gfx::TextureId reused = gfx::texture("reused").size(8, 8).build()!!;
    assert(reused != mask, "same slot, new generation => different id");
    assert(@catch(gfx::width(mask)) == gfx::STALE_HANDLE);
    assert(@catch(gfx::width((gfx::TextureId)0xDEAD_BEEF)) == gfx::STALE_HANDLE, "garbage id");

    // пул ограничен
    sz made = 0;
    while (true)
    {
        if (catch err = gfx::texture("filler").size(2, 2).build())
        {
            assert(err == gfx::OUT_OF_SLOTS);
            break;
        }
        made++;
    }
    io::printfn("live textures: %d (filled %d more slots)", gfx::live_count(), made);
    io::printfn("reused id: slot %d gen %d", gfx::slot_of(reused), gfx::generation_of(reused));
}
