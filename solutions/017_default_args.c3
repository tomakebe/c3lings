// =====================================================================
//  017 · Аргументы по умолчанию и именованные аргументы
// =====================================================================
//
//  АРГУМЕНТЫ ПО УМОЛЧАНИЮ
//  Параметру можно задать значение по умолчанию. Тогда при вызове его
//  можно не передавать:
//
//      fn int damage(int base, int multiplier = 2) => base * multiplier;
//
//      damage(10);       // 20 — multiplier взят по умолчанию
//      damage(10, 3);    // 30
//
//  В C такого нет — там пишут несколько функций или передают
//  «магические» значения вроде -1.
//
//  ИМЕНОВАННЫЕ АРГУМЕНТЫ
//  При вызове можно указать имя параметра: `имя: значение`. Это делает
//  вызов самодокументирующимся и позволяет пропускать параметры по
//  умолчанию в середине списка:
//
//      fn void open(String title, int width = 800, int height = 600) { ... }
//
//      open("Editor", height: 300);        // width = 800 по умолчанию
//      open(title: "Game", width: 1024);
//
//  Правила (проверяются компилятором):
//  * сначала идут позиционные аргументы, потом именованные;
//  * именованные аргументы должны идти В ТОМ ЖЕ ПОРЯДКЕ, что и
//    параметры в объявлении ("Named arguments must always be declared
//    in order"). Переставлять их нельзя — это сделано, чтобы порядок
//    вычисления аргументов всегда совпадал с порядком в коде.
//
//  ЗАДАЧА: исправьте три места с `// <-`. Программа должна напечатать:
//
//      Game: 800x600 windowed
//      Editor: 800x300 windowed
//      Tiny: 320x240 windowed
//      Movie: 1920x600 fullscreen
//      damage: 20 30
//
import std::io;

fn void open_window(String title, int width = 800, int height = 600, bool fullscreen = false)
{
    io::printfn("%s: %dx%d %s", title, width, height, fullscreen ? "fullscreen" : "windowed");
}

fn int damage(int base, int multiplier = 2) => base * multiplier;

fn void main()
{
    open_window("Game");
    open_window("Editor", height: 300);
    open_window("Tiny", 320, 240);
    open_window("Movie", width: 1920, fullscreen: true);

    io::printfn("damage: %d %d", damage(10), damage(10, 3));
}
