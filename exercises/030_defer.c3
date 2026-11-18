// =====================================================================
//  030 · defer
// =====================================================================
//
//  `defer <statement>;` postpones running the statement until the
//  moment you EXIT THE CURRENT SCOPE (the `{ }` block), no matter how
//  that exit happens: end of the block, `return`, `break`, `continue`.
//
//      fn void work()
//      {
//          File f = open(...);
//          defer close(f);          // runs on any exit
//          if (bad) return;         // close(f) will be called
//          ...
//      }                            // and here too
//
//  Why: in C, resources are released at the end of the function, and
//  then somebody adds an early `return` — and the resource leaks. Or
//  people build a ladder of `goto cleanup`. In C3 it's "open it, then
//  immediately write the defer that closes it": the paired operation
//  sits right next to it and can't be skipped.
//
//  ORDER: multiple defers run in REVERSE order (last declared, first
//  run — LIFO). That's natural: resources are released in the reverse
//  order of acquisition.
//
//      {
//          defer io::printn("A");
//          defer io::printn("B");
//          io::printn("C");
//      }                            // prints C, B, A
//
//  A defer is tied to the BLOCK, not to the function (unlike Go): a
//  defer in a loop body fires at the end of EVERY iteration.
//
//  You can defer a whole block too: `defer { ...several statements... }`.
//  There are also `defer catch` / `defer try`, which work with errors —
//  exercise 035.
//
//  TASK: fix the places marked `// <-`. The program should print:
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
                                                // <- close the file on any exit
    if (fail)
    {
        io::printfn("error in %s", name);
        return false;
    }
    io::printfn("read %s", name);
    io::printfn("close %s", name);              // <- an early return never gets here
    return true;
}

fn void main()
{
    assert(load("save.dat", false));
    assert(!load("broken.dat", true));

    {
        defer io::printn("2. save");            // <- defers run in reverse order
        defer io::printn("3. unlock");
        io::printn("1. edit");
    }

    for (int i = 0; i < 3; i++)
    {
        defer io::print("]");                   // at the end of every iteration
        io::printf("[%d", i);
    }
    io::printn();
}
