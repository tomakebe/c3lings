// =====================================================================
//  086 · Рефлексия: поля, размеры, смещения
// =====================================================================
//
//  Рефлексия — это возможность программы узнать о своих типах: какие у
//  структуры поля, какого они типа, где лежат в памяти. В C есть только
//  `sizeof` и `offsetof`; в C++ до C++26 рефлексии полей нет вовсе
//  (отсюда макросы вроде BOOST_DESCRIBE); в Zig — `@typeInfo`. В C3
//  практически всё доступно при компиляции через `::` у типа и
//  `$reflect(...)` у значения.
//
//  Свойства типа (константы компиляции):
//
//      Foo::size          // размер в байтах (sizeof)
//      Foo::alignment     // выравнивание
//      Foo::name          // "Foo";  Foo::qname — "mymodule::Foo"
//      Foo::kind          // TypeKind.STRUCT
//      Foo::typeid        // typeid — его можно хранить и в рантайме
//      Foo::members       // compile-time список полей
//
//  Каждый элемент `Foo::members` описывает поле:
//
//      $f.name     // "x"
//      $f.type     // typeid поля: $f.type.name, $f.type.size, $f.type.kind
//      $f.offset   // смещение в байтах от начала структуры (offsetof)
//      $f.size     // размер поля
//
//  `::members` — «нетипизированный» compile-time список, поэтому
//  перебирают его через `$foreach` (или берут по константному индексу
//  `Foo::members[1].name`). Положить его в рантайм-переменную нельзя.
//
//  Для выражений есть `$reflect`:
//
//      $reflect(p.x).offset        // смещение поля
//      $reflect(Particle.y).offset // можно и через тип
//      $reflect(p).size
//
//  Зачем знать раскладку. Компилятор выравнивает поля: `double` должен
//  лежать по адресу, кратному 8, поэтому после `char` вставляются
//  7 байт пустоты (padding). Порядок полей влияет на размер структуры:
//
//      struct Bad  { char a; double b; char c; }   // 24 байта
//      struct Good { double b; char a; char c; }   // 16 байт
//
//  Для массива из миллиона частиц это мегабайты и промахи кеша. Часто
//  правило «сортируйте поля по убыванию выравнивания» экономит память
//  бесплатно. (Подробнее о раскладке — в упражнении 124.)
//
//  typeid доступен и в рантайме: `typeid t = Foo::typeid; t.size,
//  t.kind, t.name` — но `members` есть только при компиляции.
//
//  ЗАДАЧА:
//    1. В макросе `layout` посчитайте суммарный размер полей (`used`) и
//       напечатайте для каждого поля строку как в ожидаемом выводе.
//    2. Поля `Particle` расположены неудачно. Переставьте их (не меняя
//       типы и имена), чтобы структура заняла 16 байт.
//
module layout_demo;
import std::io;

struct Particle
{
    char alive;
    double x;
    short id;
    float y;
}

struct Vec3
{
    float x, y, z;
}

macro void layout($Type)
{
    io::printfn("%s: size=%d align=%d", $Type::name, $Type::size, $Type::alignment);
    usz used = 0;
    $foreach $f : $Type::members:
        // TODO: напечатайте строку о поле $f и добавьте его размер к used
    $endforeach
    io::printfn("  padding=%d", $Type::size - used);
}

fn void main()
{
    layout(Particle);
    layout(Vec3);

    $assert Particle::size == 16 : "Particle should fit in 16 bytes";

    Particle p;
    io::printfn("offset of p.y via $reflect: %d", $reflect(p.y).offset);
    io::printfn("second member: %s", Particle::members[1].name);
    io::printfn("kind: %s, qname: %s", Particle::kind, Particle::qname);

    typeid t = Vec3::typeid;      // рантайм-значение
    io::printfn("runtime typeid: size=%d kind=%s", t.size, t.kind);
}
