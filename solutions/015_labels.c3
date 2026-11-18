// =====================================================================
//  015 · Labels: break LABEL and continue LABEL
// =====================================================================
//
//  In nested loops `break` and `continue` only affect the innermost
//  loop. In C, to get out of two loops at once, you set up a flag or
//  write a `goto`. C3 has no `goto` at all, but you can give a loop (as
//  well as a `switch` or a do block) a LABEL and refer to it:
//
//      for ROWS: (int y = 0; y < h; y++)
//      {
//          for (int x = 0; x < w; x++)
//          {
//              if (grid[y][x] == target) break ROWS;    // leave both loops
//              if (grid[y][x] < 0) continue ROWS;       // on to the next y
//          }
//      }
//
//  Note where the label goes: AFTER the keyword and BEFORE the
//  parentheses, followed by a colon. Not like in C/Java (`ROWS: for (...)`),
//  but
//
//      for NAME: (...)
//      while NAME: (...)
//      switch NAME: (...)
//      do NAME: { ... };
//
//  Label names are written in UPPERCASE (like constants).
//
//  `continue ROWS` jumps straight to the next iteration of the outer
//  loop (its step `y++` is executed).
//
//  TASK:
//  1. Compute the sum of each row of the table, but skip rows that
//     contain a negative number entirely (don't print them).
//  2. Find the first cell holding the value 7 and stop searching completely.
//  Fix the places marked `// <-`. The program should print:
//
//      row 0 sum 6
//      row 2 sum 24
//      found 7 at row 2, col 0
//      cells checked: 7
//
import std::io;

fn void main()
{
    int[3][3] grid = {
        { 1, 2, 3 },
        { 4, -5, 6 },
        { 7, 8, 9 },
    };

    for ROWS: (int y = 0; y < 3; y++)
    {
        int sum = 0;
        for (int x = 0; x < 3; x++)
        {
            if (grid[y][x] < 0) continue ROWS;
            sum += grid[y][x];
        }
        io::printfn("row %d sum %d", y, sum);
    }

    int checked = 0;
    for SEARCH: (int y = 0; y < 3; y++)
    {
        for (int x = 0; x < 3; x++)
        {
            checked++;
            if (grid[y][x] == 7)
            {
                io::printfn("found 7 at row %d, col %d", y, x);
                break SEARCH;
            }
        }
    }
    io::printfn("cells checked: %d", checked);
}
