1. `|` and `&` are on the same precedence level in C3 — add parentheses the way it was intended.
2. In C3 `<<` binds tighter than `+`. To add first, you need parentheses.
3. `ichar` holds values from -128 to 127. What comes "after" 127 when it wraps around?
