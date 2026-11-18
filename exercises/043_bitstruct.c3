// =====================================================================
//  043 · `bitstruct` — bit fields done right
// =====================================================================
//
//  C has bit fields (`unsigned x : 3;`), but their memory layout
//  depends on the compiler, so for file formats, network protocols and
//  hardware registers people hardly use them — they write masks and
//  shifts by hand: `(v >> 5) & 0x3F`. That's easy to get wrong.
//
//  C3 has `bitstruct` instead — a struct with an EXPLICIT bit layout
//  inside a single "backing" integer (the backing type):
//
//      bitstruct Rgb565 : ushort     // all fields live in one ushort
//      {
//          uint b : 0..4;            // bits 0-4 inclusive (5 bits)
//          uint g : 5..10;           // bits 5-10 (6 bits)
//          uint r : 11..15;          // bits 11-15 (5 bits)
//      }
//
//  * The range `a..b` is INCLUSIVE: `0..4` is 5 bits, values 0..31.
//  * The field type (uint, int, bool, char...) is the type you get
//    when reading. An `int` field is signed: `int t : 0..2` holds -4..3.
//  * `bool flag : 7;` — a single bit. If a bitstruct has ONLY bools,
//    you can omit the numbers — they're assigned in order from 0.
//  * Bit numbers can't go beyond the size of the backing type:
//    a `char` only has bits 0..7.
//  * A bitstruct's size equals its backing type's size: `Rgb565::size == 2`.
//
//  You work with it just like a struct:
//
//      Rgb565 c = { .r = 31, .g = 0, .b = 0 };
//      c.g = 63;
//      ushort raw = (ushort)c;            // the whole thing as a number
//      Rgb565 d = (Rgb565)raw;            // and back
//      Flags f = { .visible, .solid };    // a bool field with no value = true
//
//  Bitstructs support `&`, `|`, `^`, `~` — just like masks.
//  You can't take the address of a field (`&c.g`) — bits have no address.
//
//  Gotcha: if you write a CONSTANT that doesn't fit into a field, the
//  compiler reports an error. But a variable's value is silently
//  truncated to the right number of low bits when written.
//
//  TASK: fix the three spots marked with `// <-`.
//
import std::io;

// A color in RGB565 format: 5 bits of red, 6 bits of green, 5 bits of blue.
bitstruct Rgb565 : char // <- 16 bits won't fit into a char
{
    uint b : 0..4;
    uint g : 5..9; // <- green needs 6 bits
    uint r : 11..15;
}

bitstruct Flags : char
{
    bool visible;   // bit 0
    bool selected;  // bit 1
    bool solid;     // bit 2
    bool dirty;     // bit 3
}

fn void main()
{
    Rgb565 white = { .r = 31, .g = 63, .b = 31 };
    Rgb565 green = { .g = 63 };
    io::printfn("white = 0x%04x, green = 0x%04x, size = %d",
                (ushort)white, (ushort)green, Rgb565::size);
    assert((ushort)white == 0xFFFF && (ushort)green == 0x07E0);

    Rgb565 c = (Rgb565)(ushort)0xF81F; // magenta: red + blue
    io::printfn("r=%d g=%d b=%d", c.r, c.g, c.b);

    Flags f = { .visible, .solid };
    Flags mask = { .solid, .dirty };
    io::printfn("flags = %d, common = %d", (char)f, (char)(f & mask));
    assert((char)f == ???); // <- what number do the visible and solid bits make?
}
