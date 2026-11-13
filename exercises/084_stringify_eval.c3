// =====================================================================
//  084 · `$stringify`, `$eval`, `$Typeof`, `$Typefrom`
// =====================================================================
//
//  Четыре функции, которые превращают код в данные и обратно — во время
//  компиляции.
//
//  `$stringify(выражение)` -> строка с текстом выражения. Особенно полезна
//  с `#`-параметрами: `$stringify(#e)` даёт текст ровно так, как его
//  написали в месте вызова (аналог `#x` в макросах C):
//
//      macro void @show(#e) { io::printfn("%s => %s", $stringify(#e), #e); }
//      @show(1 + 2 * 3);     // "1 + 2 * 3 => 7"
//
//  `$eval(строка)` -> идентификатор. Обратная операция: compile-time
//  строку превращает в имя переменной, функции или поля:
//
//      int x;
//      $eval("x") = 3;                    // то же, что x = 3
//      $eval("cmd_" +++ $name)(a, b);     // вызвать cmd_add / cmd_mul
//      cfg.$eval("width") = 640;          // поле по имени
//
//  Строка должна быть константой компиляции (литерал, `$`-переменная,
//  результат `+++`), а результат — ОДНИМ идентификатором (можно с
//  модулем: "io::printn"). `$eval("a.b")` или `$eval("1 + 2")` нельзя.
//  Это вам не `eval` из JavaScript: никакого выполнения строк в рантайме,
//  просто способ сконструировать имя. В C похожее делают склейкой токенов
//  `##` (`cmd_##name`), но там это текст, а здесь — проверенное имя:
//  опечатка даст ошибку "could not be found".
//
//  `$Typeof(выражение)` -> ТИП выражения (вы уже им пользовались).
//  Выражение при этом НЕ вычисляется: `$Typeof(counter += 100)` не
//  изменит counter. Аналог `decltype` из C++ и `typeof` из GNU C/C23.
//
//  `$Typefrom(...)` -> тип из typeid или из строки с именем типа:
//
//      $Typefrom("double") d = 1.25;
//      $Typefrom(long::typeid) l = 9;
//
//  Удобно, когда тип известен только как typeid — например, из
//  `$f.type` при обходе полей структуры (`$Typefrom($f.type) tmp;`).
//
//  Вместе они позволяют писать «табличный» код: имена команд, полей,
//  настроек хранятся в строках, а компилятор связывает их с настоящими
//  функциями и полями и проверяет, что они существуют.
//
//  ЗАДАЧА:
//    1. В `@run` вызовите функцию `cmd_<name>` через `$eval`.
//    2. В `@show` напечатайте текст выражения.
//    3. В `@set_field` присвойте значение полю с именем `$field`.
//    4. Объявите переменную `backup` того же типа, что `counter`, не
//       называя тип явно.
//
import std::io;

fn int cmd_add(int a, int b) => a + b;
fn int cmd_sub(int a, int b) => a - b;
fn int cmd_mul(int a, int b) => a * b;

macro int @run(String $name, int a, int b)
{
    return ???(a, b);
}

macro void @show(#e)
{
    io::printfn("%s => %s", "???", #e);
}

macro void @set_field(#obj, String $field, value)
{
    // TODO
}

struct Config
{
    int width;
    int height;
    bool fullscreen;
}

fn void main()
{
    assert(@run("add", 7, 5) == 12);
    assert(@run("mul", 7, 5) == 35);
    io::printfn("add=%d sub=%d mul=%d", @run("add", 7, 5), @run("sub", 7, 5), @run("mul", 7, 5));

    @show(1 + 2 * 3);
    int lives = 3;
    @show(lives * 100);

    Config cfg;
    @set_field(cfg, "width", 640);
    @set_field(cfg, "height", 480);
    @set_field(cfg, "fullscreen", true);
    assert(cfg.width == 640 && cfg.height == 480 && cfg.fullscreen);
    io::printfn("config: %dx%d fullscreen=%s", cfg.width, cfg.height, cfg.fullscreen);

    ushort counter = 5;
    ??? backup = counter;
    $assert $Typeof(backup)::typeid == ushort::typeid;
    $Typeof(counter += 100) untouched = 0;   // counter НЕ изменится
    assert(counter == 5);
    io::printfn("counter=%d backup=%d (%s)", counter, backup, $Typeof(backup)::name);

    $Typefrom("double") d = 1.25;
    $Typefrom(long::typeid) big = 1L << 40;
    io::printfn("d=%.2f big=%d (%s)", d, big, $Typeof(big)::name);
    io::printn($stringify(cfg.width * 2));
}
