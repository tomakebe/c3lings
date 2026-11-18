// =====================================================================
//  031 · Optional: `T?`, `excuse` and returning an error with `ERR~`
// =====================================================================
//
//  Welcome to the second part of the course! We start with the most
//  important intermediate topic: error handling.
//
//  In C, a function that can fail usually returns a "magic" value:
//  -1, NULL, 0... and stashes an error code off to the side in errno.
//  Forgetting the check is very easy, and -1 is sometimes a perfectly
//  legitimate result.
//
//  C3 has Optionals for this. The type `int?` means:
//  "this holds EITHER a regular int, OR the reason why there is no int".
//
//      int? a = 5;            // Optional with the result 5
//      int? b = NOT_FOUND~;   // empty Optional with the "excuse" NOT_FOUND
//
//  The reason for emptiness is a value of type `fault`. New `fault`
//  values are declared at the top level with the keyword `excuse`:
//
//      excuse FILE_MISSING;                    // one value
//      excuse BAD_FORMAT, TOO_LONG;            // several at once
//      excuse { NO_SPACE, NO_ACCESS }          // or as a block in braces
//
//  Each such value is globally unique. (In older versions of C3 this
//  was called `faultdef` - don't be surprised if you see it online.)
//
//  The key point is the `~` suffix. On its own, `FILE_MISSING` is just
//  an ordinary value of type `fault` (you can store it in a variable,
//  compare it). But `FILE_MISSING~` turns it into an EMPTY Optional:
//
//      fault f  = FILE_MISSING;    // just an error value
//      int?  x  = FILE_MISSING~;   // empty Optional
//
//  A function that can fail returns an Optional:
//
//      fn int? find_index(int[] arr, int value)
//      {
//          foreach (i, v : arr) if (v == value) return i;
//          return NOT_FOUND~;      // <- the `~` is required!
//      }
//
//  `fn void? f()` is a function that returns nothing but can report
//  an error. There can be no variable of type `void?`.
//
//  Optionals are "contagious": an `int?` value can't be put into a plain
//  `int` - the compiler won't let you forget about the error. An
//  expression involving an Optional becomes an Optional too: if `a` is
//  an `int?`, then `a + 1` is also an `int?`.
//
//  How to peek inside (more on unwrapping in 032):
//
//      @ok(x)      // true if x holds a result
//      @catch(x)   // the fault inside x, or the "empty" fault if x is fine
//
//  The "empty" fault behaves like false in conditions: `if (@catch(x)) ...`.
//
//  TASK: fix the program (4 places are marked with `// <-`). The program
//  checks itself with asserts and prints the result.
//
import std::io;

excuse NOT_A_DIGIT;
// <- declare the TOO_BIG error here

fn int digit_value(char c) // <- this function can fail
{
    if (c < '0' || c > '9') return NOT_A_DIGIT; // <- return an EMPTY Optional
    return c - '0';
}

fn int? two_digits(char hi, char lo)
{
    if (hi > '5' && hi <= '9') return TOO_BIG~;
    int? h = digit_value(hi);
    int? l = digit_value(lo);
    // If h or l is empty, the whole expression will also be an empty
    // Optional with the first error encountered. No need to check explicitly!
    return h * 10 + l;
}

fn void main()
{
    int? seven = digit_value('7');
    int bad = digit_value('x'); // <- there might be no number here

    assert(@ok(seven));
    assert(!@ok(bad));
    assert(@catch(bad) == NOT_A_DIGIT);
    assert(!@catch(seven)); // seven holds no error

    assert(@ok(two_digits('4', '2')));
    assert(@catch(two_digits('9', '9')) == TOO_BIG);
    assert(@catch(two_digits('?', '1')) == NOT_A_DIGIT);

    fault f = @catch(two_digits('7', '7'));
    if (f == TOO_BIG) io::printn("77 is too big");
    if (!@catch(two_digits('1', '2'))) io::printn("12 is fine");
    io::printn("optionals work!");
}
