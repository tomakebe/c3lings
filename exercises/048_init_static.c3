// =====================================================================
//  048 · `@init`, `@finalizer` and `static` local variables
// =====================================================================
//
//  STATIC INITIALIZERS. Global variables in C3 can only be initialized
//  with constant expressions. But what if a table has to be COMPUTED at
//  startup (a sine table, plugin registration, parsing settings)? You
//  could call `init_everything()` on the first line of main, but that's
//  easy to forget. C3 can run functions automatically:
//
//      fn void build_tables() @init       { ... }  // BEFORE main
//      fn void flush_logs()   @finalizer  { ... }  // AFTER main returns
//
//  The functions must take no parameters and return void.
//
//  The order is set by priority: `@init(1100)`, `@init(2000)`. The
//  SMALLER the number, the EARLIER it runs (the same goes for
//  @finalizer). The recommended range is 1024 to 65535; without a
//  number the priority is the latest (65535). If one initialization
//  depends on another, an explicit priority is a must — declaration
//  order in the file guarantees nothing.
//
//  @finalizer runs on normal program termination (returning from main
//  or exit). On a crash/kill it's not guaranteed. These aren't C++
//  destructors, they're the equivalent of `atexit` /
//  `__attribute__((destructor))`.
//
//  STATIC LOCAL VARIABLES — just like in C:
//
//      fn int next_id()
//      {
//          static int counter = 1;   // initialized ONCE
//          return counter++;         // and keeps its value between calls
//      }
//
//  It's essentially a global variable that's only visible inside the
//  function. Without `static` the variable would be created anew (= 1)
//  on every call. A static's initializer, like a global's, must be a
//  constant.
//
//  TASK: fix the three spots marked with `// <-`. Note that the last
//  line of output is printed AFTER main.
//
import std::io;

int scale;
int[6] table;
int ids_issued;

fn void load_config() @init(1100)
{
    scale = 10;
    io::printn("init: config loaded");
}

fn void build_table() @init(1000) // <- the table uses scale, which load_config sets
{
    foreach (i, &v : table) *v = (int)i * scale;
    io::printn("init: table built");
}

fn void shutdown() // <- must run after main
{
    io::printfn("shutdown: %d ids issued", ids_issued);
}

fn int next_id()
{
    int counter = 1; // <- the value must persist between calls
    ids_issued++;
    return counter++;
}

fn void main()
{
    io::printn("main: start");
    io::printfn("table = %s", table);
    assert(table[5] == 50);
    int a = next_id();
    int b = next_id();
    int c = next_id();
    io::printfn("ids: %d %d %d", a, b, c);
    assert(c == 3);
    io::printn("main: end");
}
