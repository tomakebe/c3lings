// =====================================================================
//  044 · SIMD vectors `int[<4>]`, swizzle, reductions
// =====================================================================
//
//  Mind the angle brackets: `int[4]` is an array, while `int[<4>]` is
//  a VECTOR. (Not to be confused with C++'s `std::vector` — that's
//  List in the standard library.) A vector is a small fixed-length
//  bundle of numbers on which operations are performed ELEMENT-WISE,
//  and the compiler tries to use the CPU's SIMD instructions for that
//  (SSE/AVX/NEON) — one instruction for all the elements at once.
//
//      float[<4>] a = { 1, 2, 3, 4 };
//      float[<4>] b = a * 2 + 1;      // { 3, 5, 7, 9 }
//      float[<4>] c = 0.5;            // a scalar is "broadcast": { .5, .5, .5, .5 }
//
//  Elements can only be numbers, bools or pointers. Indexing `a[2]`,
//  `foreach`, `.len`, and assigning to an array and back all work.
//
//  SWIZZLE — picking/reordering components by the names x y z w
//  (or r g b a for colors):
//
//      int[<3>] v = { 11, 22, 33 };
//      v.x         // 11
//      v.zyx       // { 33, 22, 11 }
//      v.xxy       // { 11, 11, 22 } — repeats are allowed
//      v.xy = v.yx // and so is assignment
//
//  REDUCTIONS and handy methods (no imports needed):
//      .sum() .product() .max() .min()   — boil a vector down to one number
//      .dot(other)                       — the dot product
//      .length() .normalize() .distance(o) — float/double only
//
//  COMPARISONS. `==` and `!=` compare whole vectors and yield a `bool`.
//  But `<`, `>` and friends CAN'T be applied to vectors — you need the
//  element-wise methods `.comp_lt/.comp_le/.comp_gt/.comp_ge/.comp_eq/.comp_ne`,
//  which return a vector of bools. The argument must be a vector too (a
//  scalar won't be broadcast here — write `{ 0, 0, 0, 0 }` or declare a
//  variable). A vector of bools is folded with `.and()` (all true?) and
//  `.or()` (at least one true?).
//
//  `%s` prints a vector as `[<1, 2, 3>]`.
//
//  TASK: fix the three spots marked with `// <-`.
//
import std::io;

fn void main()
{
    // Four units: health and damage taken per turn.
    int[<4>] hp = { 100, 40, 75, 10 };
    int[<4>] damage = { 30, 50, 25, 5 };
    hp -= damage;
    io::printfn("hp after hit: %s", hp);

    int total_damage = damage.sum(); // <- the sum of all elements
    io::printfn("total damage: %d", total_damage);
    assert(total_damage == 110);

    int[<4>] zero = 0;
    bool[<4>] alive = hp.comp_gt(zero); // <- element-wise "greater than zero"
    io::printfn("alive: %s, all alive: %s, anyone alive: %s",
                alive, alive.and(), alive.or());

    // Color RGB -> BGR by reordering the components.
    char[<3>] rgb = { 0x11, 0x22, 0x33 };
    char[<3>] bgr = rgb.zyx; // <- reverse the order of the components
    io::printfn("bgr: %s", bgr);
    assert(bgr == { 0x33, 0x22, 0x11 });

    float[<2>] dir = { 3, 4 };
    io::printfn("length %.1f, normalized %s", dir.length(), dir.normalize());
}
