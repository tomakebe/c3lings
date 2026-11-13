// =====================================================================
//  119 · Форматирование generic-контейнеров
// =====================================================================
//
//  Отладочная печать — инфраструктура, на которой держится вся
//  разработка: логи, ассерты с контекстом, консоль движка, инспектор
//  в редакторе. Хорошая система форматирования позволяет напечатать
//  ЛЮБОЕ значение через один и тот же `%s`, включая вложенные
//  контейнеры: `[<"hp", 100>, <"mp", 30>]`.
//
//  КАК ЭТО УСТРОЕНО В C3
//  ---------------------
//  `io::printf` и `string::tformat` получают аргументы как `any` (указатель
//  + typeid). Форматтер для `%s` смотрит на тип: числа, строки, enum'ы,
//  массивы и срезы он печатает сам, а для пользовательского типа
//  проверяет, реализует ли тот интерфейс Printable:
//
//      interface Printable
//      {
//          fn String to_constant_string() @optional;
//          fn sz? to_format(Formatter* formatter) @optional;
//      }
//
//  Достаточно объявить метод с атрибутом @dynamic — он попадёт в
//  таблицу динамических методов типа, и форматтер найдёт его во время
//  исполнения:
//
//      fn sz? Vec2f.to_format(&self, Formatter* f) @dynamic
//      {
//          return f.printf("(%.2f, %.2f)", self.x, self.y);
//      }
//
//  Возвращается число записанных символов, ошибки вывода пробрасываются
//  через `!`. Внутри можно рекурсивно звать `f.printf("%s", elem)` —
//  так вложенные контейнеры печатаются сами собой: каждый уровень
//  отвечает только за свои скобки и разделители. Так же устроены
//  fmt::formatter в C++20/fmtlib, Display/Debug в Rust, __repr__ в Python.
//
//  Без to_format структура печатается обобщённо (см. упр. 088) — но это
//  нестабильный «отладочный» вид. Для generic-контейнера метод пишется
//  ОДИН раз и работает для всех инстанциаций: Stack{int},
//  Stack{Pair{String, int}}, Stack{Stack{int}}...
//
//  ТОНКОСТИ
//  --------
//  * Debug против Display: строки внутри контейнера принято печатать
//    в кавычках (иначе `["a, b"]` и `["a", "b"]` неотличимы). В generic-
//    коде это решается на этапе компиляции: `$if Type::typeid == String::typeid:`.
//  * Возвращайте суммарное число символов — его используют выравнивание
//    и обрезка в форматтере.
//  * to_format не должен аллоцировать на куче — печать часто зовут из
//    горячих путей и из обработчиков ошибок.
//  * Печать указателя на структуру через %s печатает адрес — передавайте
//    значение (или разыменовывайте).
//
//  ЗАДАЧА: реализуйте to_format для Vec2f, Pair и Stack (TODO). Формат
//  виден в ожидаемом выводе в конце main.
//
import std::io;

struct Vec2f
{
    float x, y;
}

fn sz? Vec2f.to_format(&self, Formatter* f) @dynamic
{
    // TODO: "(x, y)" с двумя знаками после точки
    return f.printf("(%.2f, %.2f)", self.x, self.y);
}

struct Pair <Left, Right>
{
    Left first;
    Right second;
}

// Строки в кавычках, остальное — через %s.
macro sz? @print_elem(Formatter* f, value)
{
    $if $Typeof(value)::typeid == String::typeid:
        return f.printf("\"%s\"", value);
    $else
        return f.printf("%s", value);
    $endif
}

fn sz? Pair.to_format(&self, Formatter* f) @dynamic
{
    // TODO: "<first, second>", элементы через @print_elem
    sz n = f.print("<")!;
    n += @print_elem(f, self.first)!;
    n += f.print(", ")!;
    n += @print_elem(f, self.second)!;
    n += f.print(">")!;
    return n;
}

const STACK_CAP = 8;

struct Stack <Type>
{
    Type[STACK_CAP] items;
    sz len;
}

fn void Stack.push(&self, Type v)
{
    assert(self.len < STACK_CAP);
    self.items[self.len++] = v;
}

fn sz Stack.length(&self) @operator(len) => self.len;
fn Type Stack.get(&self, sz i) @operator([]) => self.items[i];

fn sz? Stack.to_format(&self, Formatter* f) @dynamic
{
    // TODO: "[a, b, c]", пустой — "[]"; элементы через @print_elem
    sz n = f.print("[")!;
    foreach (i, v : self.items[:self.len])
    {
        if (i > 0) n += f.print(", ")!;
        n += @print_elem(f, v)!;
    }
    n += f.print("]")!;
    return n;
}

// ---------------------------------------------------------------- проверка

alias Stat = Pair{String, int};
// Вложенные инстанциации (Stack{Stack{int}}) в теле функции записать нельзя —
// компилятор требует alias:
alias IntStack = Stack{int};
alias StrStack = Stack{String};
alias Nested = Stack{IntStack};
alias Deep = Stack{Pair{Vec2f, StrStack}};

macro @expect(String want, value)
{
    String got = string::tformat("%s", value);
    assert(got == want, "formatted as '%s', expected '%s'", got, want);
    io::printn(got);
}

fn void main()
{
    @pool()
    {
        @expect("(1.50, -2.00)", (Vec2f){ 1.5, -2 });

        Stack{int} empty;
        @expect("[]", empty);

        Stack{int} nums;
        for (int i = 1; i <= 4; i++) nums.push(i * i);
        @expect("[1, 4, 9, 16]", nums);

        Stack{String} words;
        words.push("a, b");
        words.push("c");
        @expect("[\"a, b\", \"c\"]", words);

        Stack{Stat} stats;
        stats.push({ "hp", 100 });
        stats.push({ "mp", 30 });
        @expect("[<\"hp\", 100>, <\"mp\", 30>]", stats);

        Nested nested;
        nested.push(nums);
        nested.push(empty);
        Stack{int} one;
        one.push(-1);
        nested.push(one);
        @expect("[[1, 4, 9, 16], [], [-1]]", nested);

        Deep deep;
        deep.push({ { 0, 0.25 }, words });
        @expect("[<(0.00, 0.25), [\"a, b\", \"c\"]>]", deep);

        // и в составе обычного формата
        io::printfn("player at %s has %s", (Vec2f){ 3, 4 }, stats);
    };
}
