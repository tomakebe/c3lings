// =====================================================================
//  e0901 · Ключи сортировки draw call'ов
// =====================================================================
//
//  Сначала прочитайте engine/docs/09_rendering.md (разделы
//  «Командный буфер» и «Ключи сортировки»).
//
//  Фронтенд рендерера собирает за кадр тысячи draw call'ов в
//  произвольном порядке: так их выдаёт обход сцены. Но GPU хочет их в
//  совсем другом порядке:
//
//    * сначала по слою/проходу (мир -> эффекты -> UI);
//    * непрозрачные — ДО полупрозрачных (блендинг требует, чтобы под
//      полупрозрачным уже лежало всё непрозрачное);
//    * непрозрачные сгруппированы по материалу (меньше смен состояния),
//      а внутри материала — спереди назад (front-to-back), чтобы
//      ранний z-тест отбрасывал перекрытые фрагменты;
//    * полупрозрачные — строго сзади вперёд (back-to-front), иначе
//      смешивание даст неверный цвет; материал тут не важен.
//
//  Классический приём (Bitsquid, «Order your graphics draw calls
//  around!» Кристера Эриксона) — упаковать всё это в одно 64-битное
//  целое, где старшие биты = самые важные критерии. Тогда весь порядок
//  кадра = одна сортировка массива u64 (а это ещё и radix sort).
//
//  В C3 раскладку ключа удобно описать через `bitstruct`:
//
//      bitstruct DrawKey : ulong
//      {
//          ushort id         : 0..15;   // младшие биты
//          uint   depth      : 16..39;  // 24 бита глубины
//          ...
//      }
//
//  Поля читаются и пишутся как обычные (`k.depth = 5;`), а сам ключ
//  приводится к числу и обратно: `(ulong)k`, `(DrawKey)u`. Компилятор
//  сам делает сдвиги и маски — и не даст перепутать границы полей.
//
//  Глубину нужно квантовать: float из [near, far] -> целое в 24 бита:
//
//      q = (uint)((d - near) / (far - near) * 0xFF_FFFF)
//
//  со «зажимом» (clamp) значений за пределами диапазона. Чтобы
//  полупрозрачные шли сзади вперёд, им пишут ИНВЕРТИРОВАННУЮ глубину:
//  `0xFF_FFFF - q` — тогда больший d даёт меньший ключ.
//
//  ЗАДАЧА: реализуйте `quantize_depth` и `make_key` (места помечены
//  TODO). Для полупрозрачных поле material должно быть 0 — порядок
//  между ними определяет только глубина. main() сама проверит порядок.
//
import std::io;

const uint DEPTH_MAX = 0xFF_FFFF;

bitstruct DrawKey : ulong
{
    ushort id          : 0..15;   // кто это (для отладки и стабильности)
    uint   depth       : 16..39;  // 24 бита квантованной глубины
    ushort material    : 40..54;  // 15 бит id материала
    bool   translucent : 55;      // 0 = непрозрачный, 1 = полупрозрачный
    char   layer       : 56..63;  // слой/проход: 0 мир, 1 эффекты, 2 UI...
}

<*
 Квантует глубину d из [near, far] в 24 бита. Значения вне диапазона
 зажимаются: d <= near -> 0, d >= far -> DEPTH_MAX.
*>
fn uint quantize_depth(float d, float near, float far)
{
    // TODO
    if (d <= near) return 0;
    if (d >= far) return DEPTH_MAX;
    return (uint)((d - near) / (far - near) * (float)DEPTH_MAX);
}

fn ulong make_key(char layer, bool translucent, ushort material, float view_depth, ushort id)
{
    DrawKey k;
    k.layer = layer;
    k.translucent = translucent;
    k.id = id;
    uint q = quantize_depth(view_depth, 0.0f, 100.0f);
    // TODO: непрозрачные — материал + глубина как есть;
    //       полупрозрачные — материал 0 + инвертированная глубина.
    if (translucent)
    {
        k.material = 0;
        k.depth = DEPTH_MAX - q;
    }
    else
    {
        k.material = material;
        k.depth = q;
    }
    return (ulong)k;
}

// ---------------------------------------------------------------------
// Ниже менять ничего не нужно.

struct Draw
{
    String name;
    char layer;
    bool translucent;
    ushort material;
    float depth;
    ulong key;
}

fn void sort_by_key(Draw[] draws)
{
    // Вставками: для 10 элементов в самый раз (и сортировка стабильная).
    for (usz i = 1; i < draws.len; i++)
    {
        Draw d = draws[i];
        usz j = i;
        while (j > 0 && draws[j - 1].key > d.key)
        {
            draws[j] = draws[j - 1];
            j--;
        }
        draws[j] = d;
    }
}

fn void main()
{
    // Квантование.
    assert(quantize_depth(0.0f, 0.0f, 100.0f) == 0);
    assert(quantize_depth(-5.0f, 0.0f, 100.0f) == 0, "clamp below near");
    assert(quantize_depth(100.0f, 0.0f, 100.0f) == DEPTH_MAX);
    assert(quantize_depth(1e9f, 0.0f, 100.0f) == DEPTH_MAX, "clamp above far");
    assert(quantize_depth(50.0f, 0.0f, 100.0f) == 8388607);
    assert(quantize_depth(15.0f, 10.0f, 20.0f) == 8388607, "near is subtracted");
    assert(quantize_depth(1.0f, 0.0f, 100.0f) < quantize_depth(2.0f, 0.0f, 100.0f));

    // Раскладка: поля ключа на своих местах.
    ulong k = make_key(2, false, 7, 100.0f, 3);
    io::printfn("key(ui, opaque, mat 7, far, id 3) = %016x", k);
    assert(k == 0x02_00_07_FFFFFF_0003);
    ulong t = make_key(1, true, 9, 100.0f, 4);
    io::printfn("key(fx, translucent, far, id 4)   = %016x", t);
    assert(t == 0x01_80_00_000000_0004, "translucent: material 0, inverted depth");

    Draw[] draws = {
        { "ui_text",      2, true,  1, 0.5f,  0 },
        { "glass_near",   0, true,  4, 10.0f, 0 },
        { "rock_far",     0, false, 2, 90.0f, 0 },
        { "tree_near",    0, false, 1, 5.0f,  0 },
        { "smoke",        1, true,  6, 30.0f, 0 },
        { "rock_near",    0, false, 2, 20.0f, 0 },
        { "glass_far",    0, true,  4, 70.0f, 0 },
        { "tree_far",     0, false, 1, 60.0f, 0 },
        { "ui_panel",     2, false, 3, 0.5f,  0 },
        { "water",        0, true,  5, 40.0f, 0 },
    };
    foreach (i, &d : draws) d.key = make_key(d.layer, d.translucent, d.material, d.depth, (ushort)i);
    sort_by_key(draws);

    io::printn("submission order after sort:");
    foreach (d : draws)
    {
        DrawKey dk = (DrawKey)d.key;
        io::printfn("  L%d %s mat=%2d depth=%08d  %s", dk.layer, dk.translucent ? "T" : "O",
                    dk.material, dk.depth, d.name);
    }

    String[] expected = { "tree_near", "tree_far", "rock_near", "rock_far",
                          "glass_far", "water", "glass_near",
                          "smoke", "ui_panel", "ui_text" };
    foreach (i, d : draws) assert(d.name == expected[i], "wrong order at %d: %s", i, d.name);
    io::printn("order ok");
}
