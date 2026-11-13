// =====================================================================
//  065 · Файлы: запись, чтение, ошибки ввода-вывода
// =====================================================================
//
//  Работа с файлами — модуль `std::io::file` (подключается вместе с
//  `import std::io;`). Тип файла — `File`.
//
//  Открытие — как fopen в C, с теми же режимами ("r", "w", "a", "rb"...).
//  Но вместо NULL и errno — Optional:
//
//      File? f = file::open("data.txt", "r");
//
//  Ошибки — значения из `io::`: `io::FILE_NOT_FOUND`, `io::NO_PERMISSION`,
//  `io::FILE_IS_DIR`, `io::EOF`... Обрабатываются всем, что вы знаете
//  из 031–036: `!` (пробросить), `!!` (паника), `if (catch err = ...)`.
//
//  Типичная функция, работающая с файлом, возвращает Optional и
//  пробрасывает ошибки наверх:
//
//      fn void? save(String path)
//      {
//          File f = file::open(path, "w")!;   // не открылся — выходим с ошибкой
//          defer (void)f.close();             // закроется при ЛЮБОМ выходе
//          io::fprintfn(&f, "x = %d", 42)!;   // printf в файл
//      }
//
//  Почему `defer (void)f.close()` так важен: запись буферизуется, и
//  данные реально попадают на диск при `close()` (или `flush()`). Не
//  закрыли — другой код, читающий файл, увидит его пустым, а программа
//  потеряет дескриптор. (`io::fprintfn` сам делает flush после каждой
//  строки, а `io::fprintf` и `f.write` — нет.) `(void)` нужен, потому что close() возвращает
//  `void?`, а молча выбросить Optional C3 не даёт.
//
//  Запись:  `io::fprintf(&f, ...)`, `io::fprintfn(&f, ...)`,
//           `io::fprintn(&f, "строка")`, `f.write(байты)`.
//           File — это OutStream, поэтому передаём указатель `&f`.
//  Чтение:  `io::treadline(&f)` — строка без '\n' (во временной памяти),
//           в конце файла — ошибка io::EOF. Удобный цикл:
//               while (try line = io::treadline(&f)) { ... }
//           `file::load_temp(path)` / `file::load(mem, path)` — весь файл
//           сразу как `char[]`.
//  Прочее:  `file::exists(path)`, `file::delete(path)`,
//           `file::save(path, данные)`, `file::get_size(path)`.
//
//  Пути здесь относительные — файлы создаются в текущем каталоге.
//
//  ЗАДАЧА: исправьте функции записи/чтения и обработайте отсутствующий
//  файл без паники. Ожидаемый вывод:
//      wrote 3 scores
//      total = 225
//      first line: alice 90
//      error: io::FILE_NOT_FOUND
//      cleaned up: true
//
import std::io;

struct Score
{
    String name;
    int points;
}

fn void? save_scores(String path, Score[] scores)
{
    File f = file::open(path, "w")!;
    defer (void)f.close();
    foreach (s : scores) io::fprintf(&f, "%s %d\n", s.name, s.points)!;
}

fn int? total_from_file(String path)
{
    File f = file::open(path, "r")!;
    defer (void)f.close();
    int total;
    while (try line = io::treadline(&f))
    {
        String[] parts = line.tsplit(" ");
        total += parts[1].to_int()!;
    }
    return total;
}

fn void main()
{
    const String PATH = "c3lings_scores.txt";
    Score[] scores = { { "alice", 90 }, { "bob", 75 }, { "carol", 60 } };

    save_scores(PATH, scores)!!;
    io::printfn("wrote %d scores", scores.len);

    int total = total_from_file(PATH)!!;
    io::printfn("total = %d", total);

    String text = (String)file::load_temp(PATH)!!;
    io::printfn("first line: %s", text.tsplit("\n")[0]);

    if (catch err = total_from_file("c3lings_no_such_file.txt"))
    {
        io::printfn("error: %s", err);
    }

    file::delete(PATH)!!;
    io::printfn("cleaned up: %s", !file::exists(PATH));
}
