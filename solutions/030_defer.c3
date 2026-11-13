// =====================================================================
//  030 · defer
// =====================================================================
//
//  `defer <инструкция>;` откладывает выполнение инструкции до момента
//  ВЫХОДА ИЗ ТЕКУЩЕЙ ОБЛАСТИ ВИДИМОСТИ (блока `{ }`), каким бы путём
//  этот выход ни случился: конец блока, `return`, `break`, `continue`.
//
//      fn void work()
//      {
//          File f = open(...);
//          defer close(f);          // выполнится при любом выходе
//          if (bad) return;         // close(f) будет вызван
//          ...
//      }                            // и здесь тоже
//
//  Зачем: в C освобождение ресурсов пишут в конце функции, а потом
//  кто-то добавляет ранний `return` — и ресурс утекает. Или пишут
//  лестницу из `goto cleanup`. В C3 «открыл — сразу написал defer
//  закрыть»: парная операция стоит рядом и не может быть пропущена.
//
//  ПОРЯДОК: несколько defer выполняются в ОБРАТНОМ порядке
//  (последним объявлен — первым выполнен, LIFO). Это естественно:
//  ресурсы освобождаются в порядке, обратном захвату.
//
//      {
//          defer io::printn("A");
//          defer io::printn("B");
//          io::printn("C");
//      }                            // печатает C, B, A
//
//  defer привязан к БЛОКУ, а не к функции (в отличие от Go): defer в
//  теле цикла срабатывает в конце КАЖДОЙ итерации.
//
//  Блок тоже можно отложить: `defer { ...несколько инструкций... }`.
//  Есть ещё `defer catch` / `defer try`, работающие с ошибками, —
//  упражнение 035.
//
//  ЗАДАЧА: исправьте места с `// <-`. Программа должна напечатать:
//
//      open save.dat
//      read save.dat
//      close save.dat
//      open broken.dat
//      error in broken.dat
//      close broken.dat
//      1. edit
//      2. save
//      3. unlock
//      [0][1][2]
//
import std::io;

fn bool load(String name, bool fail)
{
    io::printfn("open %s", name);
    defer io::printfn("close %s", name);
    if (fail)
    {
        io::printfn("error in %s", name);
        return false;
    }
    io::printfn("read %s", name);

    return true;
}

fn void main()
{
    assert(load("save.dat", false));
    assert(!load("broken.dat", true));

    {
        defer io::printn("3. unlock");
        defer io::printn("2. save");
        io::printn("1. edit");
    }

    for (int i = 0; i < 3; i++)
    {
        defer io::print("]");                   // в конце каждой итерации
        io::printf("[%d", i);
    }
    io::printn();
}
