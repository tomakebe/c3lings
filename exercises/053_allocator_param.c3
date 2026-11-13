// =====================================================================
//  053 · Параметр Allocator и владение памятью
// =====================================================================
//
//  В C функция, которая возвращает новую строку, обычно сама зовёт
//  malloc, и вызывающему остаётся гадать, чем это освобождать. В C3
//  принято иначе: функция, которая выделяет память для результата,
//  ПРИНИМАЕТ аллокатор первым параметром:
//
//      fn String repeat(Allocator allocator, String s, int times)
//      {
//          char[] buf = alloc::new_array(allocator, char, s.len * times);
//          ...
//      }
//
//  `Allocator` — это интерфейс (о них подробнее в 059). В stdlib есть
//  несколько готовых реализаций, а `mem` и `tmem` — просто значения
//  этого типа:
//      mem                — обычная куча (malloc/free);
//      tmem               — временный аллокатор текущего @pool;
//      ArenaAllocator     — арена поверх вашего буфера (хоть на стеке);
//      TrackingAllocator  — обёртка, считающая выделения (для отладки).
//
//  Модуль `alloc::` содержит те же макросы, что и `mem::`, но с явным
//  аллокатором первым аргументом:
//      alloc::new(allocator, Foo)            ~ mem::new(Foo)
//      alloc::new_array(allocator, int, n)   ~ mem::new_array(int, n)
//      alloc::free(allocator, ptr)           ~ free(ptr)
//  (на самом деле `mem::new(...)` — это и есть `alloc::new(mem, ...)`).
//
//  СОГЛАШЕНИЯ (им следует вся стандартная библиотека):
//    * `foo(Allocator a, ...)` — результат выделен в `a`; ВЛАДЕЕТ им
//      вызывающий и освобождает через ТОТ ЖЕ аллокатор;
//    * `tfoo(...)` — то же самое, но в `tmem`: ничего освобождать не
//      нужно, живёт до конца текущего @pool. Обычно это однострочник:
//          fn String trepeat(String s, int n) => repeat(tmem, s, n);
//    * освобождать память «чужим» аллокатором — ошибка (free(ptr) от
//      памяти из арены или из tmem уронит программу).
//
//  Выигрыш: ОДНА функция работает с любой стратегией памяти — вызывающий
//  сам решает, куча это, временная арена или буфер на стеке.
//
//  ЗАДАЧА:
//    1. `repeat` игнорирует свой параметр и всегда выделяет в куче —
//       исправьте, чтобы память бралась из `allocator`.
//    2. Допишите `trepeat` по соглашению об именах.
//    3. Освободите `b` правильным аллокатором.
//  Ожидаемый вывод:
//      heap:    ababab
//      tracked: xyzxyz (1 allocation, 6 bytes)
//      temp:    -----
//      arena:   ====
//
import std::io;

fn String repeat(Allocator allocator, String s, int times)
{
    char[] buf = mem::new_array(char, s.len * times);   // <- а параметр allocator?
    for (int i = 0; i < times; i++)
    {
        buf[i * s.len : s.len] = s[..];   // копируем s в нужный кусок buf
    }
    return (String)buf;
}

fn String trepeat(String s, int times) => ???;   // TODO

fn void main()
{
    @assert_leak()
    {
        // 1) Куча: владеем результатом, освобождаем free().
        String a = repeat(mem, "ab", 3);
        defer free(a);
        io::printfn("heap:    %s", a);

        // 2) Следящий аллокатор поверх кучи: видно, кто сколько выделил.
        TrackingAllocator tracker;
        tracker.init(mem);
        defer tracker.free();

        String b = repeat(&tracker, "xyz", 2);
        io::printfn("tracked: %s (%d allocation, %d bytes)", b,
                    tracker.allocation_count(), tracker.allocated());
        free(b);   // <- b выделена НЕ в mem...
        assert(tracker.allocated() == 0, "b must be freed through the tracker");

        // 3) Временная память: освобождать не нужно.
        @pool()
        {
            io::printfn("temp:    %s", trepeat("-", 5));
        };

        // 4) Арена поверх массива на стеке: куча вообще не трогается.
        char[64] storage;
        ArenaAllocator arena;
        arena.init(&storage);
        io::printfn("arena:   %s", repeat(&arena, "=", 4));
    };
}
