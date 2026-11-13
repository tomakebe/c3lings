// =====================================================================
//  063 · Перегрузка == и <
// =====================================================================
//
//  Структуры в C3 нельзя сравнивать `==` «из коробки»: побайтовое
//  сравнение было бы ловушкой (padding, указатели, float'ы с -0.0 и NaN,
//  строки-срезы, которые равны по содержимому, но не по адресу). Если
//  для вашего типа есть осмысленное равенство — объявите его сами:
//
//      fn bool Version.equals(self, Version o) @operator(==) => ...;
//
//  После этого работают и `==`, и `!=` (он выводится автоматически).
//
//  Порядок задаётся оператором `<`:
//
//      fn bool Version.less(self, Version o) @operator(<) { ... }
//
//  Если у типа есть И `==`, И `<`, то доступны ВСЕ сравнения:
//  `<  <=  ==  !=  >=  >`. Тип становится «упорядоченным»
//  (`Version::is_ordered == true`) — и с ним сразу работают generic-
//  алгоритмы stdlib: `quicksort(срез)` без компаратора, встроенный
//  `compare_to(a, b)`, `math::max`... Это тот же механизм, что и у
//  `String`: строки сравниваются `<` по алфавиту именно так.
//
//  Типичный `<` для составного ключа — лексикографический: сравниваем
//  первое поле; если равны — второе; и т.д. Обычная ошибка — сравнивать
//  все поля независимо (`a.major < b.major && a.minor < b.minor ...`):
//  тогда 1.9.0 окажется не меньше 2.0.0.
//
//  Требования к хорошему `<`: строгий (x < x — ложь), транзитивный,
//  и согласованный с `==` (если !(a<b) && !(b<a), то a == b). Иначе
//  сортировки ведут себя непредсказуемо.
//
//  ЗАДАЧА: подключите равенство и реализуйте тело `less`.
//  Ожидаемый вывод:
//      1.2.3 == 1.2.3: true
//      1.9.0 < 2.0.0: true
//      1.10.0 > 1.9.9: true
//      sorted: 0.9.9 1.2.0 1.2.3 1.10.0 2.0.0
//      newest: 2.0.0
//
import std::io;
import std::sort;

struct Version
{
    int major, minor, patch;
}

fn bool Version.equals(self, Version o)
    => self.major == o.major && self.minor == o.minor && self.patch == o.patch;

fn bool Version.less(self, Version o) @operator(<)
{
    // TODO: лексикографическое сравнение major, затем minor, затем patch
    return false;
}

fn String Version.str(self) => string::tformat("%d.%d.%d", self.major, self.minor, self.patch);

fn void main()
{
    Version a = { 1, 2, 3 };
    Version b = { 1, 2, 3 };
    io::printfn("1.2.3 == 1.2.3: %s", a == b);
    io::printfn("1.9.0 < 2.0.0: %s", (Version){ 1, 9, 0 } < (Version){ 2, 0, 0 });
    io::printfn("1.10.0 > 1.9.9: %s", (Version){ 1, 10, 0 } > (Version){ 1, 9, 9 });
    assert(a <= b && a >= b && !(a != b));
    assert(!(a < a), "< must be strict");

    Version[] all = { { 1, 2, 3 }, { 2, 0, 0 }, { 0, 9, 9 }, { 1, 10, 0 }, { 1, 2, 0 } };
    quicksort(all);   // работает, потому что Version упорядочен
    io::print("sorted:");
    foreach (v : all) io::printf(" %s", v.str());
    io::printn();

    Version newest = all[0];
    foreach (v : all) if (v > newest) newest = v;
    io::printfn("newest: %s", newest.str());
}
