Inside `$foreach`, a field has `$f.name`, `$f.type.name`, `$f.offset`, `$f.size`.
Line format: `"  %-6s %-6s offset=%-2d size=%d"`; don't forget `used += $f.size;`.
Field order: from the largest/most-aligned to the smallest — double, float, short, char.
