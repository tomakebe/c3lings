1. The fields of an anonymous union are accessible directly: `s.radius`.
2. Both `float` and `uint` take 4 bytes, and a union is the size of its largest field.
3. Use named initialization with the flat names: `.w = 2, .h = 5`.
