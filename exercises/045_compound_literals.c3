// =====================================================================
//  045 · Compound literals, address of a temporary, copying
// =====================================================================
//
//  A COMPOUND LITERAL is a struct or array value written right inside
//  an expression, without a separate variable (just like in C99):
//
//      draw((Vec){ 3, 4 });
//      int[3] a = (int[3]){ 1, 2, 3 };
//
//  If the type is clear from context (a function parameter, an
//  assignment), you can leave it out — and that's the usual style:
//
//      draw({ 3, 4 });
//      v = { .y = 9 };     // CAREFUL: all unspecified fields get zeroed!
//
//  You can take the fields from another struct and override some of
//  them (the "splat" `...`):
//
//      Config debug = { ...release, .verbose = true };
//
//  ADDRESS OF A TEMPORARY. In C you can't take the address of a
//  literal: `&5` is an error, so you have to declare a variable. C3 has
//  a dedicated operator for this, `&&`:
//
//      set_value(&&5);                       // an int* pointing at 5
//      int s = sum(&&(int[3]){ 1, 2, 3 }, 3);
//
//  Such a pointer only lives until the end of the current function —
//  never return it to the outside. A plain `&` can't be applied to a
//  temporary — the compiler will suggest `&&`.
//
//  COPYING. Structs, just like arrays (019), are VALUES:
//
//      Squad b = a;        // ALL the bytes of the struct are copied
//
//  * A fixed-size array inside a struct is copied in full — b gets
//    its very own array.
//  * A pointer (and a slice, and a String!) is copied as an address —
//    both copies look at THE SAME data.
//  * Passing a struct to a function by value also makes a copy:
//    changes made inside the function won't reach the caller. To change
//    the original, pass a pointer.
//  * You can't compare structs with `==` (the compiler doesn't know
//    what "equal" means to you) — compare the fields.
//
//  TASK: fix the four spots marked with `// <-`. In two of them you
//  need to predict the result of copying.
//
import std::io;

struct Team
{
    String name;
    int[3] scores;
    int* bonus;
}

fn int sum(int* values, usz n)
{
    int total;
    for (usz i = 0; i < n; i++) total += values[i];
    return total;
}

fn void reset_scores(Team t) // <- the changes must reach the caller
{
    t.scores = { 0, 0, 0 };
}

fn void main()
{
    int s = sum(&(int[3]){ 4, 5, 6 }, 3); // <- the address of a temporary array
    io::printfn("sum = %d", s);

    int shared_bonus = 1;
    Team red = { "red", { 10, 20, 30 }, &shared_bonus };

    Team copy = red;
    copy.scores[0] = 99;
    *copy.bonus = 5;
    io::printfn("red: %s bonus=%d", red.scores, *red.bonus);
    assert(red.scores[0] == ???); // <- is the array inside the struct copied?
    assert(*red.bonus == ???);     // <- and the data behind the pointer?

    Team blue = { ...red, .name = "blue" };
    reset_scores(blue);
    io::printfn("%s: %s, %s: %s", red.name, red.scores, blue.name, blue.scores);
    assert(sum(&blue.scores, 3) == 0);
}
