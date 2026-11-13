// =====================================================================
//  e1706 · Настоящий dlopen: загрузка библиотеки во время работы
// =====================================================================
//
//  До сих пор «модули» были функциями внутри одной программы. Теперь —
//  настоящая динамическая загрузка. В C3 0.8.5 она кроссплатформенная
//  и живёт в std::os:
//
//      DylibHandle lib = os::dlopen("libfoo.so", { .resolve_now = true });
//      if (!lib) ...                               // не нашли / не загрузили
//      void* sym = os::dlsym(lib, "foo_init");     // адрес символа или null
//      FooInitFn init = (FooInitFn)sym;            // привести к типу функции
//      ...
//      lib.close();                                // dlclose / FreeLibrary
//
//  Есть и Optional-варианты: os::dlopen_try, os::dlsym_try,
//  os::dlopen_any("a.so", "b.so") — первый, что загрузится.
//
//  Важнейшее: dlsym возвращает void*, а ТИП вы утверждаете сами
//  приведением. Компилятор не может проверить, что функция в
//  библиотеке действительно `fn double(double)`. Ошиблись — получите
//  мусор или падение. Поэтому в своих модулях экспортируют ОДНУ
//  функцию get_api(), а дальше работает проверяемая таблица (e1701).
//
//  Чтобы не зависеть от сборки отдельной .so, загрузим системную
//  математическую библиотеку C и найдём в ней cos и sqrt — ровно так же
//  хост ищет `game_update` в вашей game.so. Полный рецепт горячей
//  перезагрузки собственного модуля — в engine/docs/17_hot_reload.md.
//
//  ЗАДАЧА: реализуйте load_math (перебор кандидатов имени, загрузка,
//  поиск обоих символов; при любой неудаче — закрыть библиотеку и
//  вернуть false).
//
import std::io, std::os;

alias UnaryFn = fn double(double);

struct MathLib
{
    DylibHandle lib;
    UnaryFn cos;
    UnaryFn sqrt;
}

// Имя библиотеки зависит от платформы.
const ZString[*] CANDIDATES = { "libm.so.6", "libm.so", "libm.dylib", "/usr/lib/libSystem.B.dylib", "ucrtbase.dll", "msvcrt.dll" };

fn bool MathLib.load_math(&self)
{
    foreach (name : CANDIDATES)
    {
        DylibHandle lib = os::dlopen(name, { .resolve_now = true });
        if (!lib) continue;
        void* c = os::dlsym(lib, "cos");
        void* s = os::dlsym(lib, "sqrt");
        if (!c || !s)
        {
            lib.close();
            continue;
        }
        self.lib = lib;
        self.cos = (UnaryFn)c;
        self.sqrt = (UnaryFn)s;
        return true;
    }
    return false;
}

fn void MathLib.unload(&self)
{
    if (self.lib) self.lib.close();
    *self = {};
}

fn void main()
{
    MathLib m;
    assert(m.load_math(), "не удалось загрузить математическую библиотеку");
    assert(m.lib && m.cos && m.sqrt);
    io::printfn("cos(0) = %.3f", m.cos(0.0));
    io::printfn("sqrt(2) = %.3f", m.sqrt(2.0));
    io::printfn("cos(pi) = %.3f", m.cos(3.14159265358979));

    DylibHandle none = os::dlopen("definitely_not_a_library_42.so");
    assert(!none, "несуществующая библиотека должна давать null");
    if (catch err = os::dlopen_try("definitely_not_a_library_42.so")) io::printfn("missing: %s", err);

    m.unload();
    assert(!m.lib && m.cos == null, "после выгрузки указатели обнулены");
    io::printn("unloaded");
}
