// =====================================================================
//  e1304 · Текстовый конфиг через рефлексию: ключ = значение
// =====================================================================
//
//  Сначала прочитайте engine/docs/13_serialization.md (разделы 13.7–13.8).
//
//  Бинарь — для машины, текст — для человека: конфиги графики, cvar'ы,
//  настройки редактора, исходные сцены, которые мержат в git. Тот же
//  обход полей, что в e1303, пишет и читает и текст:
//
//      # graphics.cfg
//      window.width = 1280
//      window.fullscreen = false
//      gamma = 2.200
//
//  Вложенные структуры дают имена через точку. Префикс склеивается во
//  время компиляции оператором `+++`, поэтому параметр префикса —
//  compile-time: `String $prefix`, а рекурсивный вызов получает
//  `$prefix +++ $f.name +++ "."`. Посмотрите на готовый макрос `@emit`.
//
//  Чтение — обратная задача: для строки "window.width = 1280" найти поле.
//  Макрос @assign разворачивается в цепочку
//      if (key == "window.width") { cfg.window.width = val.to_int()!; return true; }
//      if (key == "window.height") ...
//  для каждого поля. Для вложенной структуры проверяем
//  `key.starts_with("window.")` и рекурсивно спускаемся.
//
//  Метаданные полей образуют маленькую property system: @tag("max", 8)
//  ограничивает значение сверху. Если значение из файла больше max —
//  записываем max и считаем это в stats.clamped (редактор бы показал
//  предупреждение).
//
//  Правила парсера:
//    * строки разделены '\n'; пробелы по краям ключа и значения не важны;
//    * пустые строки и строки, начинающиеся с '#', пропускаются;
//    * строка без '=' — ошибка SYNTAX;
//    * незнакомый ключ — НЕ ошибка: stats.unknown++ (ключ удалён из схемы
//      или опечатка; движок напишет warning в лог);
//    * плохое значение — ошибка (MALFORMED_INTEGER/MALFORMED_FLOAT из
//      to_int()/to_float(), либо BAD_VALUE для bool);
//    * при ошибке stats.line содержит номер строки (с 1), чтобы человек
//      нашёл её в файле;
//    * отсутствующие ключи оставляют значения по умолчанию — поэтому
//      парсим ПОВЕРХ объекта, заполненного default'ами;
//    * stats.applied — сколько ключей присвоено.
//
//  ЗАДАЧА: реализуйте макрос @assign и функцию parse_config (места с TODO).
//
import std::io;

excuse SYNTAX, BAD_VALUE;

struct Window
{
    int width;
    int height;
    bool fullscreen;
}

struct GraphicsConfig
{
    Window window;
    bool vsync;
    int msaa @tag("max", 8);
    float gamma;
    float fov @tag("max", 120);
}

const GraphicsConfig DEFAULTS = {
    .window = { 1280, 720, false },
    .vsync = true,
    .msaa = 4,
    .gamma = 2.2,
    .fov = 90,
};

struct ParseStats
{
    int line;
    int applied;
    int unknown;
    int clamped;
}

// ------------------------------------------------------------ запись (готово)

macro void @emit(DString* out, String $prefix, x)
{
    $foreach $f : $Typeof(x)::members:
        $switch $f.type:
            $case int:   out.appendf("%s = %d\n", $prefix +++ $f.name, x.$eval($f.name));
            $case float: out.appendf("%s = %.3f\n", $prefix +++ $f.name, x.$eval($f.name));
            $case bool:  out.appendf("%s = %s\n", $prefix +++ $f.name, x.$eval($f.name));
            $default:    @emit(out, $prefix +++ $f.name +++ ".", x.$eval($f.name));
        $endswitch
    $endforeach
}

// ------------------------------------------------------------ чтение

// Присваивает значение полю с полным именем `key` внутри *ptr.
// Возвращает true, если поле найдено, false — если такого ключа нет.
macro bool? @assign(String $prefix, ptr, String key, String val, ParseStats* stats)
{
    // TODO: $foreach по полям $Typeof(*ptr)::members и $switch $f.type:
    //   int   -> if (key == $prefix +++ $f.name) { ptr.$eval($f.name) = val.to_int()!; ... return true; }
    //   float -> то же через val.to_float()!
    //   bool  -> "true" / "false", иначе BAD_VALUE~
    //   default (вложенная структура) -> если key.starts_with($prefix +++ $f.name +++ "."),
    //            вернуть результат рекурсивного @assign с новым префиксом и &ptr.$eval($f.name)
    //   Для int и float: если у поля есть тег "max" ($if $f.has_tag("max"):) и значение
    //   больше — записать max и увеличить stats.clamped.
    //   В конце (ключ не найден) — return false.
    $foreach $f : $Typeof(*ptr)::members:
        $switch $f.type:
            $case int:
                if (key == $prefix +++ $f.name)
                {
                    ptr.$eval($f.name) = val.to_int()!;
                    $if $f.has_tag("max"):
                        if (ptr.$eval($f.name) > $f.get_tag("max"))
                        {
                            ptr.$eval($f.name) = $f.get_tag("max");
                            stats.clamped++;
                        }
                    $endif
                    return true;
                }
            $case float:
                if (key == $prefix +++ $f.name)
                {
                    ptr.$eval($f.name) = val.to_float()!;
                    $if $f.has_tag("max"):
                        if (ptr.$eval($f.name) > $f.get_tag("max"))
                        {
                            ptr.$eval($f.name) = $f.get_tag("max");
                            stats.clamped++;
                        }
                    $endif
                    return true;
                }
            $case bool:
                if (key == $prefix +++ $f.name)
                {
                    switch (val)
                    {
                        case "true": ptr.$eval($f.name) = true;
                        case "false": ptr.$eval($f.name) = false;
                        default: return BAD_VALUE~;
                    }
                    return true;
                }
            $default:
                if (key.starts_with($prefix +++ $f.name +++ "."))
                {
                    return @assign($prefix +++ $f.name +++ ".", &ptr.$eval($f.name), key, val, stats);
                }
        $endswitch
    $endforeach
    return false;
}

fn void? parse_config(String text, GraphicsConfig* cfg, ParseStats* stats)
{
    *stats = {};
    // TODO: пройти по строкам `text.split(tmem, "\n")` (stats.line = номер строки с 1),
    //   обрезать пробелы `.trim()`, пропустить пустые и комментарии '#',
    //   найти '=' через `line.index_of_char('=')` (возвращает sz?; нет '=' -> SYNTAX~),
    //   key = line[:eq].trim(), val = line[eq + 1..].trim(),
    //   вызвать @assign("", cfg, key, val, stats)! и обновить applied / unknown.
    foreach (i, raw : text.split(tmem, "\n"))
    {
        stats.line = (int)i + 1;
        String line = raw.trim();
        if (line.len == 0 || line[0] == '#') continue;
        sz? eq = line.index_of_char('=');
        if (catch eq) return SYNTAX~;
        String key = line[:eq].trim();
        String val = line[eq + 1..].trim();
        if (@assign("", cfg, key, val, stats)!)
        {
            stats.applied++;
        }
        else
        {
            stats.unknown++;
        }
    }
}

// ------------------------------------------------------------ тесты

macro void @expect_err(String what, #expr, ParseStats* stats)
{
    if (catch e = #expr)
    {
        io::printfn("%s: %s at line %d", what, e, stats.line);
        return;
    }
    unreachable("expected an error: %s", what);
}

fn void main()
{
    @pool()
    {
        // 1. Значения по умолчанию в текст.
        DString out;
        out.init(tmem);
        @emit(&out, "", DEFAULTS);
        io::printn("--- defaults ---");
        io::print(out.str_view());

        // 2. Круговой тест: текст -> объект даёт тот же объект.
        GraphicsConfig custom = { .window = { 2560, 1440, true }, .vsync = false, .msaa = 2, .gamma = 1.8, .fov = 100.5 };
        DString text;
        text.init(tmem);
        @emit(&text, "", custom);
        GraphicsConfig back = DEFAULTS;
        ParseStats st;
        parse_config(text.str_view(), &back, &st)!!;
        assert(back.window.width == 2560 && back.window.height == 1440 && back.window.fullscreen);
        assert(!back.vsync && back.msaa == 2 && back.gamma == 1.8f && back.fov == 100.5f);
        assert(st.applied == 7 && st.unknown == 0 && st.clamped == 0);
        io::printfn("round trip: applied=%d", st.applied);

        // 3. Файл, отредактированный человеком.
        String user =
            "# my settings\n"
            "\n"
            "  fov =  110.5 \n"
            "window.fullscreen=true\n"
            "msaa = 16\n"
            "shadows.quality = high   # removed in patch 1.2\n"
            "window.width = 1920\n";
        GraphicsConfig cfg = DEFAULTS;
        parse_config(user, &cfg, &st)!!;
        assert(cfg.fov == 110.5f && cfg.window.fullscreen && cfg.window.width == 1920);
        assert(cfg.window.height == 720 && cfg.vsync && cfg.gamma == 2.2f, "missing keys keep defaults");
        assert(cfg.msaa == 8, "msaa must be clamped by @tag(\"max\", 8)");
        assert(st.applied == 4 && st.unknown == 1 && st.clamped == 1);
        io::printfn("user file: applied=%d unknown=%d clamped=%d", st.applied, st.unknown, st.clamped);
        out.clear();
        @emit(&out, "", cfg);
        io::print(out.str_view());

        // 4. Ошибки с номером строки.
        GraphicsConfig tmp = DEFAULTS;
        @expect_err("no '='", parse_config("vsync = true\ngamma 2.0\n", &tmp, &st), &st);
        @expect_err("bad int", parse_config("# c\nwindow.width = wide\n", &tmp, &st), &st);
        @expect_err("bad bool", parse_config("\n\n\nvsync = maybe\n", &tmp, &st), &st);
        @expect_err("bad float", parse_config("gamma = 2.2.2\n", &tmp, &st), &st);
    };
    io::printn("text config ok");
}
