1. The fields use bits up to 15, but a `char` only has bits 0..7. You need a 16-bit backing type.
2. The range `a..b` is inclusive: `5..9` is 5 bits (max 31), but green needs 6 bits (up to 63).
   So, bits 5..10.
3. `visible` is bit 0 (value 1), `solid` is bit 2 (value 4). Add them up.
