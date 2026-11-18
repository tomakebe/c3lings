// =====================================================================
//  026 · Enumerations (enum)
// =====================================================================
//
//      enum Direction
//      {
//          NORTH,
//          EAST,
//          SOUTH,
//          WEST,
//      }
//
//  Values are written in CAPITALS. The full name is `Direction.NORTH`,
//  but wherever the type is clear from context (assignment, function
//  argument, `case`), you can omit the type name:
//  `Direction d = NORTH;`.
//
//  DIFFERENCES FROM C
//  * An enum in C3 is a real, distinct type, not a bunch of int
//    constants. It doesn't implicitly convert to a number or back.
//  * Values are always consecutive: 0, 1, 2, ... You can't write
//    `NORTH = 5` (for arbitrary values there's `constset` — exercise
//    047). The number of a value is called its ORDINAL.
//  * `%s` prints the value's NAME: "NORTH".
//
//  PROPERTIES
//      d.ordinal                   the value's number (int)
//      Direction::from_ordinal(i)  the value with that number (bounds
//                                  checked in debug builds)
//      Direction::len              the number of values (sz)
//      Direction::values           all the values (you can foreach them)
//      Direction::names            their names as strings
//  Properties of a TYPE use `::`, properties of a VALUE use a dot.
//  Casts work too: `(int)d`, `(Direction)2`.
//
//  A SWITCH ON AN ENUM MUST BE EXHAUSTIVE
//  If a `switch` on an enum has no `default`, the compiler requires ALL
//  values to be listed: "Enum value WEST was not handled in the
//  switch". Add a new value to the enum and the compiler will point out
//  every place that needs updating. That's why it's better not to
//  write `default` for enums unless you really need it.
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      NORTH (0) -> ^
//      EAST (1) -> >
//      SOUTH (2) -> v
//      WEST (3) -> <
//      turn right from WEST: NORTH
//      4 directions: [NORTH, EAST, SOUTH, WEST]
//
import std::io;

enum Direction
{
    NORTH,
    EAST,
    SOUTH,
    WEST,
}

fn String arrow(Direction d)
{
    switch (d)                                        // <- not all values are handled
    {
        case NORTH: return "^";
        case EAST:  return ">";
        case SOUTH: return "v";
    }
}

fn Direction turn_right(Direction d)
{
    int next = (d.ordinal + 1) % (int)Direction::len;
    return ???;                                       // <- the value with ordinal next
}

fn void main()
{
    foreach (d : Direction.values)                    // <- a type property is written differently
    {
        io::printfn("%s (%d) -> %s", d, d.ordinal, arrow(d));
    }
    io::printfn("turn right from WEST: %s", turn_right(WEST));
    io::printfn("%d directions: %s", Direction::len, Direction::names);
}
