В `$foreach` у поля есть `$f.name`, `$f.type.name`, `$f.offset`, `$f.size`.
Формат строки: `"  %-6s %-6s offset=%-2d size=%d"`; не забудьте `used += $f.size;`.
Порядок полей: от самых больших/выровненных к маленьким — double, float, short, char.
