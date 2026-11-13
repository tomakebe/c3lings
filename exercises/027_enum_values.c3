// =====================================================================
//  027 · Enum с ассоциированными значениями
// =====================================================================
//
//  Часто к каждому значению enum хочется привязать данные: урон оружия,
//  цвет, имя для показа. В C для этого заводят параллельный массив
//  `weapon_damage[WEAPON_COUNT]` и надеются, что он не разойдётся с
//  enum. В C3 данные можно объявить прямо в enum:
//
//      enum Weapon : (int damage, String label)
//      {
//          FISTS { 1,  "bare fists" },
//          SWORD { 10, "iron sword" },
//      }
//
//  После двоеточия в скобках — список ассоциированных полей с типами.
//  Каждое значение обязано указать ВСЕ поля, по порядку ("Expected 2
//  associated values for this enum value"). Это и есть защита: забыть
//  урон для нового оружия невозможно.
//
//  Можно указать и тип ordinal'а: `enum Weapon : char (int damage, ...)`.
//
//  Доступ — как к полям структуры:
//
//      Weapon w = SWORD;
//      io::printn(w.damage);       // 10
//      io::printn(w.label);        // "iron sword"
//
//  Данные хранятся в константной таблице; сам enum по-прежнему всего
//  лишь маленькое число-ordinal.
//
//  ПОИСК ПО ЗНАЧЕНИЮ ПОЛЯ
//  `Weapon::lookup_field(label, "iron sword")` ищет первое значение, у
//  которого поле `label` равно заданному. Результат — Optional
//  (`Weapon?`), потому что такого значения может и не быть. Как и в 023,
//  проще всего задать значение по умолчанию через `??`:
//
//      Weapon w = Weapon::lookup_field(label, "laser") ?? FISTS;
//
//  ЗАДАЧА: исправьте три места с `// <-`. Программа должна напечатать:
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
    BOW   { "long bow" },                          // <- урон лука — 7
}

fn int total_damage(Weapon w, int hits) => ??? * hits;   // <- урон оружия w

fn void main()
{
    foreach (w : Weapon::values)
    {
        io::printfn("%s: %s, damage %d", w, w.label, w.damage);
    }
    io::printfn("total damage of 3 hits: %d", total_damage(SWORD, 3));

    Weapon picked = ???;                           // <- найдите оружие с label "long bow"
    io::printfn("picked: %s", picked);

    Weapon unknown = Weapon::lookup_field(label, "laser") ?? FISTS;
    io::printfn("unknown -> %s", unknown);
}
