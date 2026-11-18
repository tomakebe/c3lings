// =====================================================================
//  013 · switch: the basics
// =====================================================================
//
//  `switch` looks like the C one, but with an important difference:
//  every `case` ends with an IMPLICIT `break`. There is no fallthrough
//  into the next `case`:
//
//      switch (x)
//      {
//          case 1:
//              io::printn("one");      // and that's it, we don't go further
//          case 2:
//              io::printn("two");
//          default:
//              io::printn("other");
//      }
//
//  In C a forgotten `break` is one of the most common bugs. Here you
//  don't need to write it at all (although `break` inside a case is
//  allowed — it simply leaves the switch early).
//
//  SEVERAL LABELS FOR ONE BRANCH
//  An EMPTY `case` (with no statements) falls through into the next one.
//  That's how several values are merged into one branch:
//
//      case 'a':
//      case 'e':
//      case 'i':
//          vowels++;               // for 'a', 'e' and 'i'
//
//  The flip side: if you want some case to do NOTHING, you can't just
//  leave it empty — it would fall through! Put at least a `break;`
//  in it.
//
//  Listing values with commas (`case 1, 2:`) is not allowed.
//
//  In C3 `switch` works not only with integers and characters but also
//  with strings (`case "move":`) — the contents are compared.
//
//  TASK: count the letters in a phrase. Vowels are a, e, i, o, u; the
//  letter 'y' is not counted at all; spaces are counted separately;
//  everything else is a consonant. Fix the places marked `// <-`. The
//  program should print:
//
//      vowels=11 spaces=8 consonants=23
//      move costs 1
//      attack costs 3
//      dance costs 0
//
import std::io;

fn int cost(String command)
{
    switch (command)
    {
        case "move":
            return 1;
        case "attack":
            return 3;
        default:
            return 0;
    }
}

fn void main()
{
    String text = "the quick brown fox jumps over the lazy dog";
    int vowels = 0;
    int spaces = 0;
    int consonants = 0;

    for (int i = 0; i < text.len; i++)
    {
        switch (text[i])
        {
            case 'a':                       // <- add the other vowels
                vowels++;
            case 'y':                       // <- 'y' shouldn't end up anywhere
            case ' ':
                spaces++;
            default:
                consonants++;
        }
    }

    io::printfn("vowels=%d spaces=%d consonants=%d", vowels, spaces, consonants);
    io::printfn("move costs %d", cost("move"));
    io::printfn("attack costs %d", cost("attack"));
    io::printfn("dance costs %d", cost("dance"));
}
