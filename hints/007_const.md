1. Constant names in C3 must be uppercase: `MAX_HP` (which is how it's used below).
2. The array is declared as `int[SLOT_COUNT]`, but there's no such constant — there's only
   a regular variable `slot_count`. Turn it into a constant with the right name
   (constants can be declared inside a function too).
