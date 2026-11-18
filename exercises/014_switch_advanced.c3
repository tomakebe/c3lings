// =====================================================================
//  014 · switch: nextcase, ranges and switch without an expression
// =====================================================================
//
//  NEXTCASE — EXPLICIT FALLTHROUGH
//  Since C3 has no implicit fallthrough, there is an explicit statement
//  for it, `nextcase`: "continue with the next case".
//
//      switch (level)
//      {
//          case 2:
//              io::printn("two");
//              nextcase;               // go on to case 1
//          case 1:
//              io::printn("one");
//      }
//
//  You can also jump to a specific value: `nextcase 5;` — as if the
//  switch evaluated its expression again and got 5. Or to the default
//  branch: `nextcase default;`. This makes state machines easy to write.
//
//  RANGES
//  `case 1..5:` matches the values from 1 to 5 INCLUSIVE.
//  It works for characters too: `case 'a'..'z':`.
//
//  SWITCH WITHOUT AN EXPRESSION
//  If there is no `(expression)` after `switch`, every label is a
//  condition (a bool), and the first branch whose condition is true
//  runs. It's a tidy replacement for a long `if / else if` chain:
//
//      switch
//      {
//          case x < 0:   io::printn("negative");
//          case x == 0:  io::printn("zero");
//          default:      io::printn("positive");
//      }
//
//  Order matters: the conditions are checked from top to bottom.
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      95 -> A, 85 -> B, 72 -> C, 40 -> F
//      level 3 bonus: 111
//      level 1 bonus: 1
//      1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz
//
import std::io;

fn String grade(int score)
{
    switch (score)
    {
        case 90..100: return "A";
        case 80..89:  return "B";
        case ???:     return "C";           // <- scores from 70 to 79
        default:      return "F";
    }
}

fn int bonus(int level)
{
    int total = 0;
    switch (level)
    {
        case 3:
            total += 100;                   // <- case 2 and case 1 should run after this
        case 2:
            total += 10;
            nextcase;
        case 1:
            total += 1;
    }
    return total;
}

fn void main()
{
    io::printfn("95 -> %s, 85 -> %s, 72 -> %s, 40 -> %s",
                grade(95), grade(85), grade(72), grade(40));
    io::printfn("level 3 bonus: %d", bonus(3));
    io::printfn("level 1 bonus: %d", bonus(1));

    for (int i = 1; i <= 15; i++)
    {
        switch
        {
            case i % 3 == 0:  io::print("Fizz");   // <- 15 should never reach this branch
            case i % 5 == 0:  io::print("Buzz");
            case i % 15 == 0: io::print("FizzBuzz");
            default:          io::print(i);
        }
        io::print(i < 15 ? " " : "\n");
    }
}
