// =====================================================================
//  021 · foreach
// =====================================================================
//
//  Walking an array with `for (int i = 0; i < arr.len; i++)` is boring
//  and invites off-by-one errors. `foreach` iterates over the elements
//  of an array or a slice (and of a string — that's just a `char[]`
//  slice too):
//
//      foreach (x : arr)          // x is a COPY of the current element
//      {
//          io::printn(x);
//      }
//
//  WITH AN INDEX: you can ask for the index (of type `usz`) before the
//  value:
//
//      foreach (i, x : arr) io::printfn("%d: %d", i, x);
//
//  You can also spell out the types: `foreach (usz i, int x : arr)`.
//
//  BY REFERENCE: the loop variable is a copy, so `x += 1` does NOT
//  change the array (and the compiler won't warn you about it!). To
//  modify elements in place, take a pointer to the element by adding
//  `&`:
//
//      foreach (&x : arr) *x += 1;    // x has type int*
//
//  (More about pointers and `*` in exercise 029. For now it's enough
//  to know that `*x` means "the thing x points to".)
//
//  IN REVERSE: `foreach_r` does the same thing, but from the end.
//
//      foreach_r (x : arr) ...        // last element first
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      1. Ann (hp 40)
//      2. Bob (hp 55)
//      3. Cid (hp 70)
//      countdown: 3 2 1 go!
//
import std::io;

fn void main()
{
    String[3] names = { "Ann", "Bob", "Cid" };
    int[3] hp = { 30, 45, 60 };

    // Heal everyone by 10.
    foreach (h : hp)                                  // <- the elements must be changed in place
    {
        h += 10;
    }
    assert(hp[0] == 40);

    foreach (name : names)                            // <- you'll need the index i
    {
        io::printfn("%d. %s (hp %d)", i + 1, name, hp[i]);
    }

    int[3] steps = { 1, 2, 3 };
    io::print("countdown:");
    foreach (s : steps) io::printf(" %d", s);         // <- we need 3 2 1
    io::printn(" go!");
}
