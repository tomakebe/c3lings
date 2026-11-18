// =====================================================================
//  039 · `alias`: synonyms for types, functions, function pointers
// =====================================================================
//
//  `alias` gives one more name to something that already exists. The
//  syntax is always the same: `alias NewName = old;`
//
//      alias Score    = int;              // type synonym
//      alias Row      = int[4];           // synonym for a compound type
//      alias Callback = fn void(int);     // function pointer type
//      alias say      = io::printn;       // function (or macro) synonym
//      alias MAX_HP   = LIMIT;            // constant/global synonym
//
//  In C, `typedef` and `#define` served this purpose. In C3, `typedef`
//  is something completely different (a new distinct type, see 040),
//  while `alias` is exactly "another name": `Score` and `int` are THE
//  SAME type, they mix freely, and `Score::size` == `int::size`.
//
//  Naming convention (the compiler enforces it!): type synonyms start
//  with an uppercase letter (`Score`), function and variable synonyms
//  with a lowercase one (`say`), constants are ALL CAPS.
//
//  Function pointers in C3 are written ONLY via alias. The type comes
//  from the function declaration with its name dropped:
//
//      fn int square(int x)    ->    fn int(int x)   (the parameter name can be omitted)
//
//      alias IntFn = fn int(int);
//      IntFn f = &square;     // the function's address is taken explicitly with &
//      int y = f(5);          // called just like a regular function
//
//  Unlike C, plain `square` without `&` can't be used as a value - the
//  compiler will ask for `&square`.
//
//  Function synonyms are handy for shortening a long name from another
//  module, or for giving a function a meaningful name without writing
//  a wrapper.
//
//  TASK: fix the three places marked with `// <-`.
//
import std::io;

alias Row = int[4];
alias IntFn = ???; // <- the type "function taking an int and returning an int"
// <- declare the synonym say for io::printn here

fn int square(int x) => x * x;
fn int negate(int x) => -x;

// Takes a plain int[4] - and Row fits, it's the same type.
fn int sum(int[4] values)
{
    int total;
    foreach (v : values) total += v;
    return total;
}

fn Row map(Row row, IntFn f)
{
    Row result;
    foreach (i, v : row) result[i] = f(v);
    return result;
}

fn void main()
{
    Row row = { 1, 2, 3, 4 };
    assert(Row::size == int::size * 4);

    Row squares = map(row, square); // <- pass the function's address
    IntFn f = &negate;
    Row negated = map(row, f);

    say("squares and negated:");
    io::printfn("%s sum=%d", squares, sum(squares));
    io::printfn("%s sum=%d", negated, sum(negated));
    assert(sum(squares) == 30 && sum(negated) == -10);
}
