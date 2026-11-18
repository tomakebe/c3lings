Tight packing without padding — `@packed` after the struct's name.
Cache-line alignment — `@align(64)` on the struct (its size will also be rounded up to 64).
An attribute can be put on a field too: `float[4] data @align(16);`.
`apply_damage` returns the new hp — assign it: `hp = apply_damage(hp, 30);`.
