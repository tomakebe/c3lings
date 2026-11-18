// =====================================================================
//  042 · Contracts `@require` / `@ensure`, doc comments `<* *>`
// =====================================================================
//
//  Optionals are for expected failures (the file isn't there, the
//  string isn't a number). But what about PROGRAMMER ERRORS — a
//  negative array size, a null where there must never be one? For
//  those, C3 has contracts.
//
//  Contracts are written in a doc comment `<* ... *>` right before the
//  function (a regular `/* */` or `//` will NOT do):
//
//      <*
//       Integer square root.
//       @param n : "a non-negative number"
//       @require n >= 0 : "square root of a negative number"
//       @ensure return * return <= n
//       @return "the largest r such that r*r <= n"
//      *>
//      fn int isqrt(int n) { ... }
//
//  * `@require cond` — a PREcondition: what the caller must guarantee.
//    You can list several separated by commas; a message goes after `:`.
//  * `@ensure cond` — a POSTcondition: what the function promises. The
//    result is available inside it under the name `return`.
//  * `@param [in] p` / `[out]` / `[inout]` — for pointers: the function
//    only reads / only writes / does both. The compiler checks this:
//    writing to an `[in]` or reading from an `[out]` is a compile error.
//  * `@return`, `@param name : "..."` — just documentation.
//  * `@return? NOT_FOUND` — which errors an Optional may return.
//
//  What the compiler does with them:
//  * in a debug (safe) build, which is the default, contracts turn
//    into checks: a violation => a panic with a clear message and the
//    call site;
//  * if the violation is visible already at compile time (the argument
//    is a constant), it's a COMPILE ERROR;
//  * in a release build the checks are removed, and the compiler is
//    allowed to USE the contracts for optimization. That's why breaking
//    a contract in release is undefined behavior, not "an error".
//
//  Contracts are documentation that never goes stale, and free asserts
//  at function boundaries, all at once.
//
//  TASK: fix the three spots marked with `// <-`. Don't touch the
//  contracts — they're correct, the code is wrong.
//
import std::io;

<*
 Integer square root (rounded down).
 @require n >= 0 : "square root of a negative number"
 @ensure return * return <= n, (return + 1) * (return + 1) > n
*>
fn int isqrt(int n)
{
    int r = 0;
    while ((r + 1) * (r + 1) <= n) r++; // <- the postcondition is violated
    return r;
}

// <- check the [in]/[out] directions in the contract below
<*
 Copies count numbers from src to dst.
 @param [out] dst : "where we write to"
 @param [in] src : "where we read from"
 @require count >= 0
*>
fn void copy_ints(int* dst, int* src, int count)
{
    for (int i = 0; i < count; i++) dst[i] = src[i];
}

const int DX = 6;
const int DY = 8;

fn void main()
{
    int dist = isqrt(DX * DX + DY * DY); // <- the hypotenuse length — the Pythagorean theorem
    io::printfn("distance = %d", dist);

    int[5] roots;
    int[5] numbers = { 0, 1, 15, 16, 99 };
    foreach (i, n : numbers) roots[i] = isqrt(n);
    int[5] copy;
    copy_ints(&copy, &roots, 5);
    io::printfn("roots = %s", copy);
    assert(dist == 10);
}
