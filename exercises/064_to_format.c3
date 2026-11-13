// =====================================================================
//  064 · Собственная печать: to_format и Printable
// =====================================================================
//
//  Что напечатает `io::printfn("%s", v)` для вашей структуры? Без
//  подсказки — что-то вроде `<struct type:5606c6c05040, addr:7ffca88d>`
//  (а `io::printn(v)` выдаст отладочный дамп `{ x: 1, y: 2 }`). Чтобы
//  тип печатался по-человечески, реализуйте интерфейс `Printable` из
//  std::io:
//
//      interface Printable
//      {
//          fn String to_constant_string() @optional;
//          fn sz? to_format(Formatter* formatter) @optional;
//      }
//
//  Главный метод — `to_format`. Ему дают `Formatter*` — того самого
//  «писателя», через которого работает printf, — и он пишет в него
//  представление значения, возвращая число записанных байт (или ошибку):
//
//      struct Vec2 (Printable) { int x, y; }
//
//      fn sz? Vec2.to_format(&self, Formatter* f) @dynamic
//      {
//          return f.printf("(%d, %d)", self.x, self.y);
//      }
//
//  Не забудьте `@dynamic` — форматтер находит метод в рантайме через
//  `any` (как в 058/059). Объявлять `(Printable)` не обязательно, но
//  желательно: тогда компилятор проверит сигнатуру.
//
//  Внутри можно звать `f.print("текст")` и `f.printf(fmt, ...)` сколько
//  угодно раз, складывая их результаты; ошибки пробрасываем `!`:
//      sz n = f.print("[")!;
//      n += f.printf("%s", self.inner)!;     // вложенный Printable!
//      return n + f.print("]")!;
//
//  Один метод — и тип печатается ВЕЗДЕ, где работает форматирование:
//  `io::printfn("%s")`, `io::printn`, `string::tformat`, `DString.appendf`,
//  запись в файл, и даже внутри контейнеров: `List{Vec2}` напечатается
//  как `[(1, 2), (3, 4)]`, потому что List.to_format печатает элементы
//  через `%s`.
//
//  ЗАДАЧА: сделайте так, чтобы Vec2 и Segment печатались красиво.
//  Ожидаемый вывод:
//      v = (1, 2)
//      segment (0, 0) -> (3, 4), length 5
//      path: [(1, 2), (3, 4), (5, 6)]
//      as string: <(7, 8)>
//
import std::io;
import std::math;
import std::collections::list;

struct Vec2 (Printable)
{
    int x, y;
}

fn sz? Vec2.to_format(&self, Formatter* f) @dynamic
{
    // TODO: напечатайте (x, y)
    return 0;
}

struct Segment (Printable)
{
    Vec2 from, to;
}

fn sz? Segment.to_format(&self, Formatter* f)
{
    int dx = self.to.x - self.from.x;
    int dy = self.to.y - self.from.y;
    sz n = f.printf("segment %s -> %s", self.from, self.to)!;
    f.printf(", length %d", (int)math::sqrt(dx * dx + dy * dy))!;
    return ???;   // сколько байт записано всего?
}

fn void main()
{
    Vec2 v = { 1, 2 };
    io::printfn("v = %s", v);

    Segment s = { { 0, 0 }, { 3, 4 } };
    io::printn(s);

    @pool()
    {
        List{Vec2} path;   // без init — временная память этого @pool
        path.push(v);
        path.push({ 3, 4 });
        path.push({ 5, 6 });
        io::printfn("path: %s", path);

        String str = string::tformat("<%s>", (Vec2){ 7, 8 });
        assert(str == "<(7, 8)>");
        io::printfn("as string: %s", str);
    };
}
