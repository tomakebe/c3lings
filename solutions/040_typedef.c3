// =====================================================================
//  040 · `typedef`: отдельные типы и `inline` typedef
// =====================================================================
//
//  В 1999 году зонд Mars Climate Orbiter разбился, потому что одна
//  часть программы считала в фунтах-силы, а другая — в ньютонах. Для
//  компилятора C и то и другое было просто `double`.
//
//  В C3 `typedef` создаёт НОВЫЙ, ОТДЕЛЬНЫЙ тип с тем же устройством,
//  что и исходный (внимание: в C `typedef` — это всего лишь синоним,
//  в C3 синоним — это `alias`, см. 039):
//
//      typedef Meters = double;
//      typedef Feet   = double;
//
//  Теперь `Meters`, `Feet` и `double` — три РАЗНЫХ типа:
//  * неявно превращаться друг в друга они не могут;
//  * функция `fn void fly(Meters m)` не примет ни `Feet`, ни `double`;
//  * явное приведение возможно: `(Meters)3.0`, `(double)m`;
//  * арифметика внутри типа работает: `Meters + Meters -> Meters`,
//    и с литералами тоже: `m * 2`, `m + 1.5` дают Meters. А вот
//    СРАВНЕНИЕ с литералом (`m > 5.0`) в 0.8.5 — ошибка: пишите
//    `m > (Meters)5.0` или `(double)m > 5.0`.
//  * Даже присваивание литерала требует приведения: `Meters m = 5.0;`
//    — ошибка, надо `Meters m = (Meters)5.0;`. (Если хочется разрешить
//    литералы, есть атрибут: `typedef Id @constinit = int;`.)
//
//  К typedef'у можно добавлять методы — у `double` их нет, а у
//  `Feet` будет:
//
//      fn Meters Feet.to_meters(self) => (Meters)((double)self * 0.3048);
//
//  Это идеальный способ сделать «идентификаторы» и «единицы
//  измерения», которые невозможно перепутать: `typedef EntityId = uint;`,
//  `typedef TextureHandle = uint;` — передать одно вместо другого
//  компилятор не даст.
//
//  INLINE TYPEDEF. Иногда строгость мешает: хочется отдельный тип со
//  своими методами, но чтобы он сам превращался в базовый там, где
//  ждут базовый тип. Для этого `inline`:
//
//      typedef Hp = inline int;
//      Hp hp = (Hp)100;
//      int x = hp;          // ок: Hp -> int неявно
//      // hp = x;           // а обратно — по-прежнему только (Hp)x
//
//  ЗАДАЧА: почините четыре места, помеченные `// <-`.
//
import std::io;

typedef Meters = double;
typedef Feet = double;
typedef Seconds = double;
typedef Hp = inline int; // <- Hp должен неявно превращаться в int

fn Meters Feet.to_meters(self) => (Meters)((double)self * 0.3048);

fn double speed(Meters distance, Seconds time) => (double)distance / (double)time;

fn bool Hp.is_alive(self) => self > 0;

fn int clamp_to_100(int value) => value > 100 ? 100 : value;

fn void main()
{
    Meters runway = (Meters)3000.0; // <- литерал — это double, а не Meters
    Feet climb = (Feet)10_000.0;
    Meters path = runway + climb.to_meters(); // <- Feet и Meters не складываются

    Seconds t = (Seconds)120.0;
    double v = speed(path, t); // <- что здесь перепутано?
    io::printfn("path = %.1f m, speed = %.2f m/s", path, v);
    assert((double)path > 6000 && (double)path < 6100);

    Hp hp = (Hp)150;
    int shown = clamp_to_100(hp);
    io::printfn("hp = %d (shown %d), alive: %s", hp, shown, hp.is_alive());
}
