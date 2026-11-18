// =====================================================================
//  028 · Unions and anonymous nested structs
// =====================================================================
//
//  UNION
//  All the fields of a union live at the SAME address and share the
//  same memory. The size of a union is the size of its largest field
//  (taking alignment into account).
//
//      union FloatBits
//      {
//          float f;
//          uint bits;
//      }
//
//  Write `f`, read `bits`: you get the bit representation of the float.
//  In C3 this kind of "reinterpretation" through a union is allowed and
//  well-defined (unlike in C++).
//
//  More often a union is used to store ONE of several values, saving
//  memory — together with a "tag" field that says what's actually in
//  there (a tagged union).
//
//  ANONYMOUS NESTED STRUCTS AND UNIONS
//  Inside a struct/union you can declare a union/struct without a field
//  name. Its fields are then accessible DIRECTLY, as if they were
//  declared in the outer struct:
//
//      struct Shape
//      {
//          ShapeKind kind;
//          union                    // no name
//          {
//              int radius;          // for a circle
//              struct               // for a rectangle
//              {
//                  int w;
//                  int h;
//              }
//          }
//      }
//
//      Shape s;
//      s.radius = 3;                // not s.something.radius
//      s.w = 2;                     // w and h share memory with radius!
//
//  Initialization also uses the "flat" names: `{ .kind = RECT, .w = 2, .h = 5 }`.
//
//  The size of a type is the `Type::size` property.
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      bits of 1.0f: 0x3f800000
//      FloatBits is 4 bytes
//      circle area ~ 27
//      rect area = 10
//      Shape is 12 bytes
//
import std::io;

union FloatBits
{
    float f;
    uint bits;
}

enum ShapeKind
{
    CIRCLE,
    RECT,
}

struct Shape
{
    ShapeKind kind;
    union
    {
        int radius;
        struct
        {
            int w;
            int h;
        }
    }
}

fn int area(Shape s)
{
    switch (s.kind)
    {
        case CIRCLE: return 3 * s.radius * s.radius;
        case RECT:   return s.w * s.h;
    }
}

fn void main()
{
    FloatBits fb;
    fb.f = 1.0f;
    io::printfn("bits of 1.0f: %#x", fb.bits);
    assert(FloatBits::size == 4);
    io::printfn("FloatBits is %d bytes", FloatBits::size);

    Shape circle = { .kind = CIRCLE, .radius = 3 };
    Shape rect = { .kind = RECT, .w = 2, .h = 5 };
    io::printfn("circle area ~ %d", area(circle));
    io::printfn("rect area = %d", area(rect));

    // kind (4 bytes) + union { int; struct { int; int; } } (8 bytes)
    io::printfn("Shape is %d bytes", Shape::size);
}
