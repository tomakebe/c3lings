// =====================================================================
//  028 · union и анонимные вложенные структуры
// =====================================================================
//
//  UNION
//  Все поля union лежат по ОДНОМУ адресу и делят одну память. Размер
//  union — размер самого большого поля (с учётом выравнивания).
//
//      union FloatBits
//      {
//          float f;
//          uint bits;
//      }
//
//  Записали `f` — прочитали `bits`: получили битовое представление
//  float. В C3 такое «переосмысление» через union разрешено и
//  определено (в отличие от C++).
//
//  Чаще union используют, чтобы хранить ОДНО из нескольких значений,
//  экономя память, — вместе с полем-«меткой», которое говорит, что
//  именно там лежит (tagged union).
//
//  АНОНИМНЫЕ ВЛОЖЕННЫЕ СТРУКТУРЫ И ОБЪЕДИНЕНИЯ
//  Внутри struct/union можно объявить union/struct без имени поля. Тогда
//  его поля доступны НАПРЯМУЮ, как будто они объявлены во внешней
//  структуре:
//
//      struct Shape
//      {
//          ShapeKind kind;
//          union                    // без имени
//          {
//              int radius;          // для круга
//              struct               // для прямоугольника
//              {
//                  int w;
//                  int h;
//              }
//          }
//      }
//
//      Shape s;
//      s.radius = 3;                // не s.something.radius
//      s.w = 2;                     // w и h делят память с radius!
//
//  Инициализация тоже по «плоским» именам: `{ .kind = RECT, .w = 2, .h = 5 }`.
//
//  Размер типа — свойство `Тип::size`.
//
//  ЗАДАЧА: исправьте три места с `// <-`. Программа должна напечатать:
//
//      bits of 1.0f: 0x3f800000
//      FloatBits is 4 bytes
//      circle area ~ 27
//      rect area = 10
//      Shape is 12 bytes
//
import std::io;

union FloatBits
{
    float f;
    uint bits;
}

enum ShapeKind
{
    CIRCLE,
    RECT,
}

struct Shape
{
    ShapeKind kind;
    union
    {
        int radius;
        struct
        {
            int w;
            int h;
        }
    }
}

fn int area(Shape s)
{
    switch (s.kind)
    {
        case CIRCLE: return 3 * s.radius * s.radius;
        case RECT:   return s.w * s.h;
    }
}

fn void main()
{
    FloatBits fb;
    fb.f = 1.0f;
    io::printfn("bits of 1.0f: %#x", fb.bits);
    assert(FloatBits::size == 4);
    io::printfn("FloatBits is %d bytes", FloatBits::size);

    Shape circle = { .kind = CIRCLE, .radius = 3 };
    Shape rect = { .kind = RECT, .w = 2, .h = 5 };
    io::printfn("circle area ~ %d", area(circle));
    io::printfn("rect area = %d", area(rect));

    // kind (4 байта) + union { int; struct { int; int; } } (8 байт)
    io::printfn("Shape is %d bytes", Shape::size);
}
