// =====================================================================
//  059 · Интерфейсы и @dynamic
// =====================================================================
//
//  `any` из 058 знает тип значения, но вызывать на нём методы можно
//  только через switch по типам. Интерфейсы дают настоящий
//  полиморфизм: «мне всё равно, что это, лишь бы умело area()».
//
//  Объявление — список методов БЕЗ параметра self:
//
//      interface Shape
//      {
//          fn double area();
//          fn String name();
//          fn double perimeter() @optional;   // можно не реализовывать
//      }
//
//  Тип объявляет, какие интерфейсы реализует, в скобках после имени,
//  а сами методы помечаются атрибутом `@dynamic`:
//
//      struct Circle (Shape) { double r; }
//      fn double Circle.area(&self) @dynamic => math::PI * self.r * self.r;
//
//  `@dynamic` означает «этот метод можно найти и вызвать в рантайме по
//  имени» — без него метод обычный, статический, и через интерфейс его
//  не видно. Если тип объявил `(Shape)`, компилятор проверит, что все
//  методы, кроме `@optional`, реализованы и помечены `@dynamic`.
//
//  Значение интерфейсного типа устроено как `any`: указатель + typeid.
//  Создаётся из УКАЗАТЕЛЯ на объект:
//      Circle c = { 1.0 };
//      Shape s = &c;              // неявно — только если Circle (Shape)
//      Shape[] all = { &c, &r };  // разнородная коллекция
//      s.area();                  // динамический вызов
//
//  Тип, не объявивший `(Shape)`, неявно в Shape не превратится (можно
//  явным кастом, но тогда проверка переносится в рантайм).
//
//  Необязательный метод перед вызовом надо проверить — иначе паника
//  «No method 'perimeter' could be found»:
//      if (&s.perimeter) ... s.perimeter() ...
//
//  Отличие от C++/Java: нет vtable внутри объекта и нет наследования
//  классов. Методы ищутся по типу в момент вызова, а структуры остаются
//  обычными C-структурами без скрытых полей.
//
//  Стандартная библиотека полна интерфейсов: `Allocator` из 053,
//  `InStream`/`OutStream` (файлы, DString), `Printable` (см. 064).
//
//  ЗАДАЧА: заставьте Rect и Square работать как Shape и аккуратно
//  вызывайте необязательный метод. Ожидаемый вывод:
//      circle: area 3.14
//      rect: area 6.00, perimeter 10.00
//      square: area 4.00, perimeter 8.00
//      total area: 13.14
//
import std::io;
import std::math;

interface Shape
{
    fn double area();
    fn String name();
    fn double perimeter() @optional;
}

struct Circle (Shape)
{
    double r;
}
fn double Circle.area(&self) @dynamic => math::PI * self.r * self.r;
fn String Circle.name(&self) @dynamic => "circle";

struct Rect (Shape)
{
    double w, h;
}
fn double Rect.area(&self) @dynamic => self.w * self.h;
fn String Rect.name(&self) @dynamic => "rect";
fn double Rect.perimeter(&self) @dynamic => 2 * (self.w + self.h);

struct Square (Shape)
{
    double side;
}
fn double Square.area(&self) @dynamic => self.side * self.side;
fn String Square.name(&self) @dynamic => "square";
fn double Square.perimeter(&self) @dynamic => 4 * self.side;

fn double total_area(Shape[] shapes)
{
    double total;
    foreach (s : shapes) total += s.area();
    return total;
}

fn void main()
{
    Circle c = { 1.0 };
    Rect r = { 2, 3 };
    Square sq = { 2 };
    Shape[] shapes = { &c, &r, &sq };

    foreach (s : shapes)
    {
        io::printf("%s: area %.2f", s.name(), s.area());
        if (&s.perimeter) io::printf(", perimeter %.2f", s.perimeter());
        io::printn();
    }
    io::printfn("total area: %.2f", total_area(shapes));
}
