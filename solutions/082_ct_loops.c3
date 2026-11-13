// =====================================================================
//  082 · `$for` и `$foreach`
// =====================================================================
//
//  Compile-time циклы не выполняются в рантайме — они РАЗВОРАЧИВАЮТСЯ:
//  компилятор копирует тело столько раз, сколько итераций, подставляя
//  значения переменных цикла как константы.
//
//      $for var $i = 0; $i < 3; $i++:
//          io::printn($i);
//      $endfor
//      // превращается в: io::printn(0); io::printn(1); io::printn(2);
//
//  Синтаксис как у `$if`: двоеточие, `$endfor`, без фигурных скобок.
//  Переменные цикла — compile-time переменные с `$`. Такие переменные
//  можно объявлять и менять внутри функций/макросов (`var $x = 0;
//  $x += 2;`), но не на верхнем уровне файла.
//
//  `$foreach` перебирает compile-time СПИСКИ:
//
//      $foreach $f : Player::members:      // поля структуры
//          io::printn($f.name);
//      $endforeach
//
//      $foreach $c : Color::values: ... $endforeach   // значения enum
//      $foreach $i, $name : Color::names: ... $endforeach  // с индексом
//
//      var $list = { 1, 2, 3 };            // «нетипизированный список»
//      $foreach $x : $list: ... $endforeach
//
//  Зачем это нужно, если есть обычный `for`?
//
//    1. Когда на каждой итерации — РАЗНЫЙ тип или разное имя. По полям
//       структуры обычным циклом не пройти: поле `hp` — int, `name` —
//       String, и обращение `p.<имя поля>` должно быть известно при
//       компиляции. С `$foreach` и `$eval` (подробно в 084) — можно:
//
//          $foreach $f : $Typeof(p)::members:
//              ... p.$eval($f.name) ...      // p.hp, p.mana, ...
//          $endforeach
//
//       Каждый элемент `::members` — описание поля: `.name` (строка),
//       `.type` (typeid), `.offset`, `.size` (см. 086).
//
//    2. Ручная развёртка мелких циклов (скалярное произведение векторов
//       фиксированной длины) — без счётчика и переходов.
//
//    3. Обход `$vaarg` (вы уже видели в 080).
//
//  В C для такого используют X-macros (`#define FIELDS X(hp) X(mana)`),
//  в C++ — рекурсивные шаблоны или (с C++26) рефлексию, в Zig —
//  `inline for` по `@typeInfo(T).Struct.fields`. В C3 это обычный
//  код с `$`.
//
//  Ограничение: тело цикла должно состоять из целых инструкций — нельзя
//  «развернуть» половину выражения. И не злоупотребляйте: развёрнутый
//  цикл на 10 000 итераций раздует и время компиляции, и бинарник.
//
//  ЗАДАЧА:
//    1. `dot` — скалярное произведение двух массивов длины `$n`,
//       развёрнутое через `$for` (без рантайм-цикла).
//    2. `sum_int_fields` — сумма всех полей типа int у структуры
//       (через `$foreach` по `::members`; сравнивайте `$f.type` с
//       `int::typeid`).
//    3. Напечатайте все значения enum `Color` с их ordinal через
//       `$foreach` (формат смотрите в ожидаемом выводе).
//
import std::io;

struct Player
{
    int hp;
    int mana;
    float speed;
    String name;
    int gold;
}

enum Color { RED, GREEN, BLUE }

macro dot(int $n, a, b)
{
    var r = a[0] * b[0];
    $for var $i = 1; $i < $n; $i++:
        r += a[$i] * b[$i];
    $endfor
    return r;
}

macro int sum_int_fields(s)
{
    int total;
    $foreach $f : $Typeof(s)::members:
        $if $f.type == int::typeid:
            total += s.$eval($f.name);
        $endif
    $endforeach
    return total;
}

macro void print_fields($Type)
{
    $foreach $f : $Type::members:
        io::printfn("  %s: %s", $f.name, $f.type.name);
    $endforeach
}

fn void main()
{
    int[4] a = { 1, 2, 3, 4 };
    int[4] b = { 5, 6, 7, 8 };
    int d = dot(4, a, b);
    assert(d == 70);
    io::printfn("dot = %d", d);

    io::printn("Player fields:");
    print_fields(Player);

    Player p = { 100, 30, 1.5, "hero", 7 };
    int total = sum_int_fields(p);
    assert(total == 137);
    io::printfn("sum of int fields = %d", total);

    $foreach $c : Color::values:
        io::printfn("%s = %d", $c, $c.ordinal);
    $endforeach

    var $squares = { 1, 4, 9, 16 };
    int sq_sum;
    $foreach $x : $squares:
        sq_sum += $x;
    $endforeach
    io::printfn("sum of squares = %d", sq_sum);
}
