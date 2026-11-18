// =====================================================================
//  019 · Fixed-size arrays
// =====================================================================
//
//  SYNTAX: the size goes on the TYPE, not on the name as in C:
//
//      int[5] scores;                 // C: int scores[5];
//      int[3] rgb = { 255, 128, 0 };
//      int[*] primes = { 2, 3, 5 };   // the size is inferred: int[3]
//      int[10] sparse = { [2] = 7, [9] = 1 };   // the rest are zeros
//
//  `int[5]` reads left to right: "an array of 5 ints". Elements you
//  don't specify are zeroed, like everything in C3. If the initializer
//  has more elements than the size allows, that's a compile error.
//
//  The array length: `scores.len` (of type `sz`, a signed size). Indices start at 0.
//  Out-of-bounds access gets caught: for a constant index at compile
//  time, for a variable index in a debug build the program aborts with
//  a clear message instead of silently corrupting memory.
//
//  AN ARRAY IS A VALUE
//  This is the big difference from C. In C an array "decays" into a
//  pointer: you can't assign it, and what actually gets passed to a
//  function is an address. In C3 a fixed-size array behaves like an
//  ordinary value (like a struct):
//
//      int[3] a = { 1, 2, 3 };
//      int[3] b = a;        // a COPY of all the elements
//      b[0] = 100;          // a is unchanged
//
//  And when passed to a function, the array is COPIED too: the function
//  works with its own copy. To get the modified array back you can
//  return it (`fn int[3] f(int[3] a)`) — or pass a pointer/slice
//  (more on that in the next exercises).
//
//  Arrays of the same type can be compared with `==` element by element,
//  and `%s` in printf prints them as `[1, 2, 3]`.
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      primes: [2, 3, 5, 7, 11] (5 items)
//      backup: [10, 20, 30]
//      doubled: [20, 40, 60]
//      equal after doubling backup? true
//
import std::io;

fn int[3] doubled(int[3] values)
{
    for (int i = 0; i < values.len; i++)
    {
        values[i] *= 2;          // we modify the local copy...
    }
    return values;               // ...and return it
}

fn void main()
{
    int[3] primes = { 2, 3, 5, 7, 11 };          // <- let the size be inferred
    io::printfn("primes: %s (%d items)", primes, primes.len);

    int[3] scores = { 10, 20, 30 };
    int[3] backup = scores;                      // a copy!
    doubled(scores);                             // <- the result is thrown away, scores is unchanged
    assert(scores[0] == 20);
    assert(backup[0] == ???);                    // <- what's in the copy?
    io::printfn("backup: %s", backup);
    io::printfn("doubled: %s", scores);

    io::printfn("equal after doubling backup? %s", doubled(backup) == scores);
}
