// =====================================================================
//  046 · Multidimensional arrays
// =====================================================================
//
//  In C3 a type reads LEFT TO RIGHT: `int[4]` is "ints, 4 of them".
//  Add another dimension: `int[4][3]` is "(ints, 4 of them), 3 of
//  them", i.e. 3 rows of 4 elements. That's the OPPOSITE order
//  compared to C!
//
//      // C:   int a[3][4];   — 3 rows of 4
//      // C3:  int[4][3] a;   — also 3 rows of 4
//
//      int[4][3] a = {
//          { 1, 2, 3, 4 },     // a[0]
//          { 5, 6, 7, 8 },     // a[1]
//          { 9, 10, 11, 12 },  // a[2]
//      };
//
//  INDEXING, on the other hand, works like in C: the outer index (the
//  row) first, then the inner one (the column): `a[2][0] == 9`. So in
//  a declaration the sizes are written "inside out", and in an access
//  "outside in". It makes sense: `a[2]` is an `int[4]`, and `a[2][0]`
//  is an `int`.
//
//      a.len       // 3 — the number of rows
//      a[0].len    // 4 — the length of a row
//
//  Just like one-dimensional arrays, multidimensional ones are values:
//  they're copied in full and laid out in memory as one chunk (row
//  after row), with size `int[4][3]::size == 48`. To pass one to a
//  function without copying, use a pointer (`Grid*`) or a slice of
//  rows `int[4][]`.
//
//  `foreach` over a 2D array walks the rows; a nested `foreach` walks
//  the elements of a row. To modify elements, take them by reference
//  with `&`: `foreach (&row : grid) foreach (&cell : row) *cell = 0;`
//
//  There are also "jagged" arrays: `int[][3]` is three slices of
//  different lengths.
//
//  In a safe build, out-of-bounds access is caught: a constant index is
//  a compile error, a computed one is a runtime panic.
//
//  TASK: fix the three spots marked with `// <-`.
//
import std::io;

const WIDTH = 6;
const HEIGHT = 3;

alias Map = char[WIDTH][HEIGHT]; // <- HEIGHT rows of WIDTH characters

fn void draw(Map* map)
{
    foreach (&row : map) io::printn((String)(*row)[..]);
}

fn int column_sum(int[4][3] m, int col)
{
    int sum;
    for (int r = 0; r < m.len; r++) sum += m[r][col]; // <- row, then column
    return sum;
}

fn void main()
{
    Map map;
    foreach (&row : map) foreach (&cell : row) *cell = '.';
    map[0][5] = '#';   // row 0, column 5
    map[2][1] = '@';
    draw(&map);
    io::printfn("rows=%d cols=%d bytes=%d", map.len, map[0].len, Map::size);

    int[4][3] m = {
        { 1, 2, 3, 4 },
        { 5, 6, 7, 8 },
        { 9, 10, 11, 12 },
    };
    assert(m[1][2] == 7); // <- which element sits in row 1, column 2?
    io::printfn("column 3 sum = %d", column_sum(m, 3));
    assert(column_sum(m, 3) == 24);
}
