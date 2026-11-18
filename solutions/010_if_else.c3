// =====================================================================
//  010 · if / else, the ternary operator and elvis
// =====================================================================
//
//  `if` looks just like in C:
//
//      if (hp <= 0)
//      {
//          io::printn("game over");
//      }
//      else if (hp < 10)
//      {
//          io::printn("low hp");
//      }
//      else
//      {
//          io::printn("ok");
//      }
//
//  The condition is a bool. Integers and pointers are allowed too (they
//  are compared with zero / null), but a bool is clearer.
//
//  CURLY BRACES
//  You can only omit `{ }` if the body is on the SAME line as the `if`:
//
//      if (x < 0) return -x;          // OK
//
//      if (x < 0)
//          return -x;                 // ERROR in C3
//
//  This protects against a classic C bug: someone adds a second line
//  with the same indentation and thinks it's inside the `if` too.
//
//  THE TERNARY OPERATOR — same as in C: `condition ? if_true : if_false`.
//
//      String s = n > 0 ? "positive" : "not positive";
//
//  ELVIS `?:` — shorthand for "the value, or a fallback if it's
//  'empty'":
//
//      a ?: b      same as   a ? a : b   (but `a` is evaluated only once)
//
//  An "empty" value is 0, false, null or the empty string "". Handy
//  for default values:
//
//      int lives = saved_lives ?: 3;      // if 0 was saved, give 3
//
//  TASK: fix the three places marked with `// <-`. The program should
//  print:
//
//      -5 -> freezing
//      12 -> cold
//      25 -> warm
//      lives: 3
//      player: anonymous
//      7 is odd
//      10 is even
//
import std::io;

fn String classify(int temp)
{
    if (temp < 0)
    {
        return "freezing";
    }
    else if (temp < 20)
    {
        return "cold";
    }
    return "warm";
}

fn String parity(int n)
{
    return n % 2 == 0 ? "even" : "odd";
}

fn void main()
{
    io::printfn("-5 -> %s", classify(-5));
    io::printfn("12 -> %s", classify(12));
    io::printfn("25 -> %s", classify(25));

    int saved_lives = 0;
    int lives = saved_lives ?: 3;
    io::printfn("lives: %d", lives);

    String nickname = "";
    String shown = nickname ?: "anonymous";
    io::printfn("player: %s", shown);

    io::printfn("7 is %s", parity(7));
    io::printfn("10 is %s", parity(10));
}
