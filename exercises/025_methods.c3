// =====================================================================
//  025 · Methods
// =====================================================================
//
//  C3 has no classes, but you can add METHODS to any type — functions
//  whose name starts with the type name and a dot:
//
//      fn int Vec2.length_sq(self)
//      {
//          return self.x * self.x + self.y * self.y;
//      }
//
//  The first parameter, named `self`, is the object the method is
//  called on. You don't need to write its type. Call it with a dot:
//
//      Vec2 v = { 3, 4 };
//      int l = v.length_sq();         // 25
//
//  This is just a convenient way to write an ordinary function call.
//  You can write the same thing explicitly: `Vec2.length_sq(v)`.
//
//  `self` OR `&self`
//  * `self` — the method gets a COPY of the object. Changes made inside
//    the method are lost (and the compiler won't warn you!). Good for
//    "read-only" methods.
//  * `&self` — the method gets a POINTER to the object and can modify
//    it. Fields are still accessed with a dot (`self.x += 1`): in C3
//    the dot works for pointers too, there's no `->` operator.
//
//      fn void Vec2.scale(&self, int k) { self.x *= k; self.y *= k; }
//
//  When you call `v.scale(2)`, the address `&v` is taken automatically.
//  With an explicit call you have to pass it yourself:
//  `Vec2.scale(&v, 2)`.
//
//  You can add methods to other people's types too (even built-in
//  ones, like `int` or `String`) — that's how all the string methods
//  from the previous exercise work.
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      length_sq: 25
//      scaled: (6, 8)
//      counter: 3
//      42 divisible by 7: true
//
import std::io;

struct Vec2
{
    int x;
    int y;
}

fn int length_sq(self)                             // <- a method of which type?
{
    return self.x * self.x + self.y * self.y;
}

fn void Vec2.scale(&self, int k)
{
    self.x *= k;
    self.y *= k;
}

struct Counter
{
    int value;
}

fn void Counter.increment(self)                    // <- the changes get lost
{
    self.value++;
}

// A method on the built-in type int.
fn bool int.divisible_by(self, int d) => self % d == 0;

fn void main()
{
    Vec2 v = { 3, 4 };
    io::printfn("length_sq: %d", v.length_sq());

    ???;                                           // <- double v using the scale method
    io::printfn("scaled: (%d, %d)", v.x, v.y);

    Counter c;
    c.increment();
    c.increment();
    Counter.increment(&c);                         // explicit call, same thing
    assert(c.value == 3);
    io::printfn("counter: %d", c.value);

    int n = 42;
    io::printfn("42 divisible by 7: %s", n.divisible_by(7));
}
