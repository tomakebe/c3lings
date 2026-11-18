// =====================================================================
//  087 · Reflecting on enums and methods
// =====================================================================
//
//  ENUM. You saw some of the properties in 026–027; here's the full picture:
//
//      Planet::len            // number of values
//      Planet::values         // all values (an array, available at runtime)
//      Planet::names          // their names as strings: { "MERCURY", ... }
//      Planet::from_ordinal(i)   // value by its number
//      Planet::members        // associated fields (mass, moons):
//                             //   $m.name, $m.type — just like for structs
//      Planet::lookup_field(moons, 2)   // value by the first match of
//                                       // an associated field (Optional)
//      p.ordinal, p.description         // number and name of a specific value
//
//  Note the `::` for properties of the TYPE and `.` for values:
//  `Dir::from_ordinal(1)`, but `Dir.NORTH`. Writing `Dir.from_ordinal`
//  is an error in 0.8.5.
//
//  A typical task is parsing a string into an enum. In C that's a manual
//  `strcmp` against every name (plus a table that people forget to update).
//  In C3 the names are always at hand: just walk `$Enum::names`.
//
//  METHODS. `Type::methods` is a compile-time list of the type's method
//  NAMES (strings). Together with `$eval` it lets you call a method by name:
//
//      $foreach $m : Robot::methods:
//          $if $m.len > 4 &&& $m[0..3] == "cmd_":
//              r.$eval($m)();          // r.cmd_left(), r.cmd_right()...
//          $endif
//      $endforeach
//
//  Compile-time strings can be compared, you can take `.len` and slices —
//  that's how methods get selected by prefix. The `&&&` operator is needed
//  so that the slice `$m[0..3]` isn't even considered for short names.
//
//  A warning from the docs: methods are registered AFTER types, so at the
//  top level (e.g. in a `$assert` outside a function) the list may be
//  incomplete. Inside functions and macros it is reliable. The order is
//  the declaration order.
//
//  This is the foundation of "automatic registration": console commands,
//  tests, event handlers — add a method with the right prefix and it gets
//  picked up on its own, with no hand-maintained tables.
//
//  TASK:
//    1. Implement `@parse_enum($Enum, s)`: return the enum value whose
//       name equals s, or the error NOT_FOUND~.
//    2. Finish `run_all_commands`: call every method on the robot whose
//       name starts with "cmd_", and after each one print
//       "<method name> -> x=<x>".
//
module enum_demo;
import std::io;

excuse NOT_FOUND;

enum Planet : (double mass, int moons)
{
    MERCURY { 0.33, 0 },
    EARTH   { 5.97, 1 },
    MARS    { 0.642, 2 },
}

enum Dir { NORTH, EAST, SOUTH, WEST }

fn Dir Dir.turn_right(self) => Dir::from_ordinal((self.ordinal + 1) % (int)Dir::len);

struct Robot
{
    int x;
}

fn void Robot.cmd_left(&self) => self.x -= 1;
fn void Robot.cmd_jump(&self) => self.x += 10;
fn void Robot.reset(&self) => self.x = 0;
fn void Robot.cmd_right(&self) => self.x += 1;

macro @parse_enum($Enum, String s)
{
    foreach (i, name : $Enum::names)
    {
        if (name == s) return $Enum::from_ordinal(i);
    }
    return NOT_FOUND~;
}

fn void run_all_commands(Robot* r)
{
    $foreach $m : Robot::methods:
        $if $m.len > 4 &&& $m[0..3] == "cmd_":
            r.$eval($m)();
            io::printfn("%s -> x=%d", $m, r.x);
        $endif
    $endforeach
}

fn void main()
{
    io::printfn("%d planets: %s", Planet::len, Planet::names);
    $foreach $m : Planet::members:
        io::printfn("associated: %s (%s)", $m.name, $m.type.name);
    $endforeach
    foreach (p : Planet::values) io::printfn("  %s mass=%.2f moons=%d", p, p.mass, p.moons);
    io::printfn("two moons: %s", Planet::lookup_field(moons, 2)!!);

    Dir d = NORTH;
    for (int i = 0; i < 5; i++)
    {
        io::printf("%s ", d);
        d = d.turn_right();
    }
    io::printn();

    Dir? south = @parse_enum(Dir, "SOUTH");
    assert(south!! == Dir.SOUTH);
    Planet? earth = @parse_enum(Planet, "EARTH");
    assert(earth!!.moons == 1);
    Dir? bad = @parse_enum(Dir, "UP");
    if (catch err = bad) io::printfn("parse UP: %s", err);
    io::printfn("parse SOUTH: %s, ordinal %d", south!!, south!!.ordinal);

    Robot r;
    run_all_commands(&r);
    assert(r.x == 10);
}
