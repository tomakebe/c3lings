// =====================================================================
//  056 · DString — построение строк
// =====================================================================
//
//  `String` в C3 — это срез `char[]`: указатель + длина, «вид» на чужие
//  байты. Он не умеет расти. Чтобы собирать строку по кусочкам, есть
//  `DString` (dynamic string) — растущий буфер символов:
//
//      DString s;
//      s.init(mem);            // или s.tinit() — во временной памяти
//      defer s.free();
//
//      s.append("abc");        // String
//      s.append('!');          // char
//      s.append_char('x');
//      s.append_repeat('-', 3);
//      s.appendf("%d + %d", 2, 2);   // как printf, но в строку
//      s.insert_at(0, ">> ");
//      s.len(), s[0], s.clear()
//      s.str_view()            // String-ВИД на текущее содержимое
//      s.copy_str(allocator)   // независимая КОПИЯ как String
//
//  DString печатается напрямую: `io::printn(s)`, `printfn("%s", s)`.
//
//  ПОДВОДНЫЙ КАМЕНЬ №1: `append` — макрос, который смотрит на тип
//  аргумента. Целое число он считает КОДОМ СИМВОЛА (Char32)! Так что
//  `s.append(42)` добавит символ '*', а вовсе не "42". Числа
//  добавляйте через `appendf("%d", n)`.
//
//  ПОДВОДНЫЙ КАМЕНЬ №2: `str_view()` не копирует — это вид на внутренний
//  буфер DString. Когда DString освобождён (или пул, где он жил, закрыт),
//  вид указывает в никуда. Если строка должна пережить DString —
//  возвращайте `copy_str(allocator)`, и пусть вызывающий её освободит
//  (соглашение из 053: аллокатор передаёт вызывающий).
//
//  Как и List/HashMap, DString без init при первой записи сам
//  инициализируется временным аллокатором.
//
//  ЗАДАЧА: в `join_ints` числа должны добавляться как текст, а
//  результат — переживать функцию. Ожидаемый вывод:
//      [1, 22, 333]
//      [] (len 2)
//      >> total: 356 <<
//
import std::io;

// Собирает "[a, b, c]" во временном DString и возвращает копию в `allocator`.
fn String join_ints(Allocator allocator, int[] xs) => @pool()
{
    DString s;
    s.tinit();
    s.append('[');
    foreach (i, x : xs)
    {
        if (i > 0) s.append(", ");
        s.appendf("%d", x);
    }
    s.append(']');
    return s.copy_str(allocator);
}

fn void main()
{
    @assert_leak()
    {
        String a = join_ints(mem, { 1, 22, 333 });
        defer free(a);
        io::printn(a);
        assert(a == "[1, 22, 333]");

        String b = join_ints(mem, {});
        defer free(b);
        io::printfn("%s (len %d)", b, b.len);

        DString line;
        line.init(mem);
        defer line.free();
        line.appendf("total: %d", 1 + 22 + 333);
        line.insert_at(0, ">> ");
        line.append(" <<");
        io::printn(line);
    };
}
