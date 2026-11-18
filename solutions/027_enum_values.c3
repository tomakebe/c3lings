// =====================================================================
//  027 · Enums with associated values
// =====================================================================
//
//  Often you want to attach data to each enum value: a weapon's damage,
//  a color, a display name. In C you'd set up a parallel array
//  `weapon_damage[WEAPON_COUNT]` and hope it never drifts out of sync
//  with the enum. In C3 you can declare the data right in the enum:
//
//      enum Weapon : (int damage, String label)
//      {
//          FISTS { 1,  "bare fists" },
//          SWORD { 10, "iron sword" },
//      }
//
//  After the colon, in parentheses, comes the list of associated fields
//  with their types. Every value must provide ALL the fields, in order
//  ("Expected 2 associated values for this enum value"). That's the
//  safety net: you can't forget the damage for a new weapon.
//
//  You can also specify the ordinal type: `enum Weapon : char (int damage, ...)`.
//
//  Access works like struct fields:
//
//      Weapon w = SWORD;
//      io::printn(w.damage);       // 10
//      io::printn(w.label);        // "iron sword"
//
//  The data lives in a constant table; the enum itself is still just a
//  small ordinal number.
//
//  LOOKUP BY FIELD VALUE
//  `Weapon::lookup_field(label, "iron sword")` finds the first value
//  whose `label` field equals the given one. The result is an Optional
//  (`Weapon?`), because there may be no such value. As in 023, the
//  simplest thing is to give a default value with `??`:
//
//      Weapon w = Weapon::lookup_field(label, "laser") ?? FISTS;
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      FISTS: bare fists, damage 1
//      SWORD: iron sword, damage 10
//      BOW: long bow, damage 7
//      total damage of 3 hits: 30
//      picked: BOW
//      unknown -> FISTS
//
import std::io;

enum Weapon : (int damage, String label)
{
    FISTS { 1,  "bare fists" },
    SWORD { 10, "iron sword" },
    BOW   { 7,  "long bow" },
}

fn int total_damage(Weapon w, int hits) => w.damage * hits;

fn void main()
{
    foreach (w : Weapon::values)
    {
        io::printfn("%s: %s, damage %d", w, w.label, w.damage);
    }
    io::printfn("total damage of 3 hits: %d", total_damage(SWORD, 3));

    Weapon picked = Weapon::lookup_field(label, "long bow") ?? FISTS;
    io::printfn("picked: %s", picked);

    Weapon unknown = Weapon::lookup_field(label, "laser") ?? FISTS;
    io::printfn("unknown -> %s", unknown);
}
