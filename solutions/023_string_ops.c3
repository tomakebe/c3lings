// =====================================================================
//  023 · Строки из стандартной библиотеки
// =====================================================================
//
//  У `String` много методов (см. lib/std/core/string.c3). Вызываются
//  они через точку: `s.trim()`. Самые полезные:
//
//      s.trim()               убрать пробельные символы по краям
//      s.starts_with("ab")    bool
//      s.ends_with(".c3")     bool
//      s.contains("needle")   bool
//      s.index_of("x")        позиция подстроки (Optional, см. ниже)
//      s.tsplit(",")          разбить по разделителю -> String[]
//      s.to_int()             разобрать число (Optional, см. ниже)
//      s.to_double()
//      s.to_upper_tcopy()     копия в верхнем регистре
//
//  Методы `trim`, срезы и т.п. НЕ копируют строку: результат — вид на
//  те же байты. Методы с буквой `t` (`tsplit`, `tconcat`,
//  `to_upper_tcopy`) выделяют память во ВРЕМЕННОМ аллокаторе — она
//  освобождается автоматически, вызывать free не надо. Подробно об
//  аллокаторах — в упражнениях 051–053; пока просто пользуйтесь
//  t-версиями.
//
//  OPTIONAL — НЕБОЛЬШОЙ АНОНС
//  Разбор числа может не удаться ("abc" — не число). Поэтому `to_int()`
//  возвращает не `int`, а `int?` — «int или ошибка». Присвоить `int?`
//  в обычный `int` нельзя: компилятор заставляет решить, что делать
//  при ошибке. Самый простой способ — оператор `??`, «значение по
//  умолчанию при ошибке»:
//
//      int n = "42".to_int() ?? 0;     // 42
//      int m = "abc".to_int() ?? -1;   // -1
//
//  Подробно об Optional — в упражнениях 031–036.
//
//  ЗАДАЧА: разберите строку сохранения игры. Исправьте три места с
//  `// <-`. Программа должна напечатать:
//
//      fields: 4
//      name: Ann
//      stats total: 147
//      bad number -> -1
//      is save: true
//      upper: ANN
//
import std::io;

fn void main()
{
    String save = "   hp=100; mp=40; gold=7; name=Ann  \n";

    String clean = save.trim();
    String[] fields = clean.tsplit("; ");
    io::printfn("fields: %d", fields.len);

    String name = "?";
    int total = 0;
    foreach (field : fields)
    {
        String[] kv = field.tsplit("=");
        String key = kv[0];
        String value = kv[1];
        if (key == "name")
        {
            name = value;
            continue;
        }
        int n = value.to_int() ?? 0;
        total += n;
    }
    io::printfn("name: %s", name);
    io::printfn("stats total: %d", total);

    io::printfn("bad number -> %d", "12abc".to_int() ?? -1);
    io::printfn("is save: %s", clean.starts_with("hp=") && clean.contains("name="));
    io::printfn("upper: %s", name.to_upper_tcopy());
}
