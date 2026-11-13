// =====================================================================
//  025 · Методы
// =====================================================================
//
//  В C3 нет классов, но к любому типу можно добавить МЕТОДЫ — функции,
//  имя которых начинается с имени типа и точки:
//
//      fn int Vec2.length_sq(self)
//      {
//          return self.x * self.x + self.y * self.y;
//      }
//
//  Первый параметр с именем `self` — объект, у которого вызван метод.
//  Тип у него писать не нужно. Вызов — через точку:
//
//      Vec2 v = { 3, 4 };
//      int l = v.length_sq();         // 25
//
//  Это просто удобная запись обычного вызова функции. То же самое можно
//  написать явно: `Vec2.length_sq(v)`.
//
//  `self` ИЛИ `&self`
//  * `self` — метод получает КОПИЮ объекта. Изменения внутри метода
//    пропадут (компилятор не предупредит!). Подходит для «читающих»
//    методов.
//  * `&self` — метод получает УКАЗАТЕЛЬ на объект и может его менять.
//    Поля всё равно доступны через точку (`self.x += 1`): в C3 точка
//    работает и для указателей, оператора `->` нет.
//
//      fn void Vec2.scale(&self, int k) { self.x *= k; self.y *= k; }
//
//  При вызове `v.scale(2)` адрес `&v` берётся автоматически. При явном
//  вызове его нужно передать самому: `Vec2.scale(&v, 2)`.
//
//  Методы можно добавлять и к чужим типам (даже встроенным, например к
//  `int` или `String`) — так устроены все строковые методы из
//  предыдущего упражнения.
//
//  ЗАДАЧА: исправьте три места с `// <-`. Программа должна напечатать:
//
//      length_sq: 25
//      scaled: (6, 8)
//      counter: 3
//      42 divisible by 7: true
//
import std::io;

struct Vec2
{
    int x;
    int y;
}

fn int Vec2.length_sq(self)
{
    return self.x * self.x + self.y * self.y;
}

fn void Vec2.scale(&self, int k)
{
    self.x *= k;
    self.y *= k;
}

struct Counter
{
    int value;
}

fn void Counter.increment(&self)
{
    self.value++;
}

// Метод встроенного типа int.
fn bool int.divisible_by(self, int d) => self % d == 0;

fn void main()
{
    Vec2 v = { 3, 4 };
    io::printfn("length_sq: %d", v.length_sq());

    v.scale(2);
    io::printfn("scaled: (%d, %d)", v.x, v.y);

    Counter c;
    c.increment();
    c.increment();
    Counter.increment(&c);                         // явный вызов, то же самое
    assert(c.value == 3);
    io::printfn("counter: %d", c.value);

    int n = 42;
    io::printfn("42 divisible by 7: %s", n.divisible_by(7));
}
