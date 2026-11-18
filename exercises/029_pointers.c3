// =====================================================================
//  029 · Pointers
// =====================================================================
//
//  Pointers in C3 are almost the same as in C:
//
//      int x = 5;
//      int* p = &x;      // & takes an address
//      *p = 7;           // * dereferences: now x == 7
//      int* q = null;    // "points nowhere" (not NULL or 0)
//
//  The `*` goes with the TYPE: `int* p`. Declaring several pointers on
//  one line (`int* a, b`) is best avoided — that corner of C is
//  confusing enough already.
//
//  FIELD ACCESS: DOT ONLY
//  There's no `->` operator. Through a pointer to a struct, a field is
//  read just like on the struct itself:
//
//      Hero* h = &hero;
//      h.hp -= 10;       // C: h->hp -= 10;
//
//  (This works for one level: for a `Hero**` you have to dereference
//  first.)
//
//  WHY POINTERS
//  Arguments are passed by value. For a function to be able to change
//  the caller's variable, you pass it the address:
//
//      fn void reset(int* value) { *value = 0; }
//      reset(&score);
//
//  POINTER ARITHMETIC
//  Just like in C: `p + 1` is the address of the NEXT ELEMENT (an
//  offset of `int::size` bytes, not 1 byte). `p[i]` is the same as
//  `*(p + i)`. The difference of two pointers is the number of elements
//  between them (of type `sz`).
//  But in C3 slices (020) are usually more convenient and safer:
//  `p[0:n]` gives you a slice with a length and bounds checking.
//
//  AN ARRAY DOES NOT DECAY TO A POINTER
//  For `int[4] arr`, the expression `&arr` has type `int[4]*` (a
//  pointer to the whole array), not `int*`. A pointer to the first
//  element is `&arr[0]`.
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      after swap: a=2 b=1
//      hero hp: 75
//      third: 30, next: 40, to last: 2
//      no target
//
import std::io;

struct Hero
{
    String name;
    int hp;
}

fn void swap(int* a, int* b)
{
    int tmp = *a;
    *a = *b;
    *b = tmp;
}

fn void damage(Hero* target, int amount)
{
    if (target == null)
    {
        io::printn("no target");
        return;
    }
    target->hp -= amount;                         // <- C3 has no ->
}

fn void main()
{
    int a = 1;
    int b = 2;
    swap(a, b);                                   // <- the function expects addresses
    io::printfn("after swap: a=%d b=%d", a, b);

    Hero hero = { "Ann", 100 };
    damage(&hero, 25);
    io::printfn("hero hp: %d", hero.hp);

    int[5] values = { 10, 20, 30, 40, 50 };
    int* first = &values[0];
    int* third = first + ???;                     // <- a pointer to 30
    io::printfn("third: %d, next: %d, to last: %d", *third, third[1], &values[^1] - third);

    damage(null, 5);
}
