// =====================================================================
//  020 · Slices
// =====================================================================
//
//  A slice `int[]` is a "window" into someone else's array: a
//  (pointer, length) pair. It doesn't own the data and doesn't copy it.
//  In C you'd pass two arguments for this — `int* data, size_t len` —
//  and constantly mix up the length. In C3 the length always travels
//  together with the pointer: `s.len`.
//
//  TAKING A SLICE (note the two different syntaxes!):
//
//      arr[1..3]    elements 1 through 3 INCLUSIVE (3 of them)
//      arr[1:3]     starting at 1, LENGTH 3 (the same thing)
//      arr[2..]     from 2 to the end
//      arr[..2]     from the start up to 2 inclusive
//      arr[..]      the whole array
//
//  INDEXING FROM THE END: `^n` means "len - n".
//      arr[^1]      the last element
//      arr[^3..]    the last three elements
//
//  Slicing works on arrays, on slices and on pointers:
//  `int* p` → `p[0:4]` is a slice of 4 elements starting at p. That's
//  how you turn a "C-style" pointer into a safe slice with a length.
//
//  A SLICE IS A VIEW, NOT A COPY
//  Writing through a slice changes the original array:
//
//      int[] mid = arr[1..2];
//      mid[0] = 99;           // arr[1] is now 99
//
//  PASSING AN ARRAY TO A FUNCTION THAT TAKES A SLICE
//  The function `fn int sum(int[] values)` works with an array of any
//  length. But an array (a value!) doesn't turn into a slice on its
//  own — you have to say explicitly that you're handing over a window
//  onto it: `sum(&arr)` or `sum(arr[..])`. Otherwise you get the error
//  "Conversions from arrays ... to slices are only permitted on
//  constant arrays".
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      sum of all: 210
//      middle: [30, 40, 50]
//      last: 60
//      after zeroing middle: [10, 20, 0, 0, 0, 60]
//      from pointer: [20, 0]
//
import std::io;

fn int sum(int[] values)
{
    int total = 0;
    for (int i = 0; i < values.len; i++) total += values[i];
    return total;
}

fn void main()
{
    int[6] numbers = { 10, 20, 30, 40, 50, 60 };

    io::printfn("sum of all: %d", sum(numbers));      // <- an array doesn't become a slice on its own

    int[] middle = numbers[???];                       // <- the elements 30, 40, 50
    assert(middle.len == 3);
    io::printfn("middle: %s", middle);

    io::printfn("last: %d", numbers[???]);             // <- the last one, using ^

    for (int i = 0; i < middle.len; i++) middle[i] = 0;
    io::printfn("after zeroing middle: %s", numbers);

    int* p = &numbers[1];
    int[] two = p[0:2];
    io::printfn("from pointer: %s", two);
}
