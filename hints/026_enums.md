1. The compiler requires the switch to handle every enum value. Add `case WEST:`.
2. The value by ordinal: `Direction::from_ordinal(next)`.
3. Type properties (`values`, `names`, `len`) are written with `::`, not with a dot.
