// =====================================================================
//  093 · Взаимодействие с C: раскладка структур, CInt, вариадики C
// =====================================================================
//
//  В прошлом упражнении мы вызывали C-функции с простыми аргументами.
//  Теперь — структуры и функции с переменным числом аргументов.
//
//  Структуры
//  ---------
//  Структура C3 раскладывается в памяти по тем же правилам, что и в C
//  на этой платформе: поля идут в порядке объявления, каждое выровнено
//  по своему выравниванию, в конце добавляется «хвостовой» padding,
//  чтобы размер был кратен выравниванию всей структуры. Поэтому C-шную
//  структуру можно просто переписать поле в поле:
//
//      // C:  typedef struct { int quot; int rem; } div_t;
//      //     div_t div(int a, int b);
//      struct DivResult { CInt quot; CInt rem; }
//      extern fn DivResult div(CInt a, CInt b);
//
//  Ключевое слово — «поле в поле». Порядок, типы и их размеры должны
//  совпадать ТОЧНО. Компилятор не может это проверить: он не видит
//  заголовков C. Ошибётесь — C-функция запишет байты не туда, а при
//  возврате структуры по значению вы получите вообще мусор из регистров
//  (маленькие структуры в ABI x86-64 возвращаются в rax/rdx, и
//  8-байтная и 16-байтная структуры возвращаются ПО-РАЗНОМУ).
//
//  Именно поэтому существуют CInt, CLong, CShort, CChar, CUInt...
//  Это псевдонимы, размер которых совпадает с типом C на целевой
//  платформе. `long` в C3 — всегда 64 бита, а `long` в C на Windows —
//  32 бита. Пишите CLong, и код будет верным везде.
//
//  Проверить раскладку можно на этапе компиляции:
//
//      $assert(Foo::size == 16);
//      $assert($reflect(Foo.field).offset == 8);
//
//  Это хорошая привычка для любой структуры, которая «смотрит» в C или
//  в бинарный файл: если кто-то поменяет поле, сборка сломается сразу.
//  `@packed` убирает padding (как __attribute__((packed))), но тогда
//  раскладка перестаёт совпадать с обычной C-структурой.
//
//  Вариадические функции C
//  -----------------------
//  printf, snprintf и т.п. объявляются с `...` в конце:
//
//      extern fn CInt snprintf(char* buf, usz n, ZString fmt, ...);
//
//  Для `...` действуют правила C: float продвигается до double, мелкие
//  целые — до int. Но формат по-прежнему никто не проверяет! Типичные
//  ловушки:
//    * `%d` ожидает CInt, `%ld` — CLong. Передали long в `%d` — UB;
//    * `%s` ожидает нуль-терминированный char*. String в C3 — это СРЕЗ
//      (ptr + len). Если передать срез, C прочитает байты от ptr до
//      первого '\0' — т.е. «до конца исходной строки», а не до конца
//      среза. Иногда это даже «работает» (когда срез — вся строка
//      целиком), что делает ошибку особенно коварной.
//      Правильно: `s.zstr_tcopy()` (нуль-терминированная копия во
//      временной памяти) или формат `%.*s` с `(CInt)s.len, s.ptr`.
//
//  Обратно из C в C3: `((ZString)&buf).str_view()` превращает
//  нуль-терминированный буфер в обычный String (без копирования).
//
//  (Для C3-кода используйте io::printfn: он типобезопасен и понимает
//  срезы, структуры с to_format и т.д. snprintf здесь — ради интеропа.)
//
//  ЗАДАЧА:
//    1. Опишите поля DivResult правильными типами.
//    2. Посчитайте вручную размер struct Tm и смещение tm_gmtoff
//       (подсказка: 9 полей CInt, затем CLong и указатель; на x86-64
//       Linux CLong и указатели — 8 байт с выравниванием 8).
//    3. Передайте имя в snprintf так, чтобы `%s` увидел ровно "Ada".
//
//  Ожидаемый вывод:
//      17 / 5 = 3 rem 2
//      Tm: size 56, tm_gmtoff at 40
//      timegm = 1709208000
//      2024-02-29 12:00:00
//      [Ada is 36 years old] (19 chars)
//
import std::io;

struct DivResult
{
    CInt quot;
    CInt rem;
}
extern fn DivResult div(CInt a, CInt b);

// struct tm из <time.h> (glibc, Linux x86-64)
struct Tm
{
    CInt tm_sec;
    CInt tm_min;
    CInt tm_hour;
    CInt tm_mday;
    CInt tm_mon;    // 0..11
    CInt tm_year;   // годы с 1900
    CInt tm_wday;
    CInt tm_yday;
    CInt tm_isdst;
    CLong tm_gmtoff;
    ZString tm_zone;
}
$assert(Tm::size == 56);
$assert($reflect(Tm.tm_gmtoff).offset == 40);

extern fn CLong timegm(Tm* t);
extern fn usz strftime(char* buf, usz max, ZString fmt, Tm* t);
extern fn CInt snprintf(char* buf, usz n, ZString fmt, ...);

fn void main()
{
    DivResult r = div(17, 5);
    assert(r.quot == 3 && r.rem == 2);
    io::printfn("17 / 5 = %d rem %d", r.quot, r.rem);
    io::printfn("Tm: size %d, tm_gmtoff at %d", Tm::size, $reflect(Tm.tm_gmtoff).offset);

    Tm t = { .tm_year = 2024 - 1900, .tm_mon = 1, .tm_mday = 29, .tm_hour = 12 };
    io::printfn("timegm = %d", timegm(&t));

    char[64] buf;
    usz n = strftime(&buf, buf.len, "%Y-%m-%d %H:%M:%S", &t);
    io::printn(((ZString)&buf).str_view());
    assert(n == 19);

    String full = "Ada Lovelace";
    String name = full[0:3];          // срез "Ada" — НЕ нуль-терминированный!
    int age = 36;
    CInt len = snprintf(&buf, buf.len, "%s is %d years old", name.zstr_tcopy(), age);
    io::printfn("[%s] (%d chars)", ((ZString)&buf).str_view(), len);
}
