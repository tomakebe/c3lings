1. Every value must provide both fields, in order: `{ 7, "long bow" }`.
2. An associated field is read with a dot: `w.damage`.
3. Use `Weapon::lookup_field(label, "long bow")` and `??` with a fallback value,
   like in the `unknown` line below.
