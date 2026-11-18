// =====================================================================
//  089 · Attributes: `@align`, `@packed`, `@nodiscard`, `@noinline`…
// =====================================================================
//
//  Attributes are annotations on declarations, written AFTER the thing
//  being declared: `fn int f() @nodiscard`, `struct S @packed { ... }`,
//  `int x @align(16);`. You've already met `@operator`, `@dynamic`,
//  `@private`, `@local`, `@init`, `@test`. In C the same things are done
//  with non-standard `__attribute__((packed))` / `__declspec(align(16))`,
//  different for every compiler; in C3 they are part of the language.
//
//  MEMORY LAYOUT
//
//    `@packed` (struct/union) — remove alignment: all fields are packed
//    tightly with no padding, and the struct's alignment is 1. Needed for
//    binary formats (file headers, network packets) where every byte has
//    its fixed place. The price is unaligned access to fields (slightly
//    slower on x86, noticeably slower on some architectures). And a trap:
//    the ADDRESS of an unaligned field can't be used as a regular `uint*`.
//    `io::printfn("%d", h.length)` implicitly takes the address (the
//    argument becomes `any`), and in safe mode the program will crash with
//    "Unaligned access". Copy the field into a local variable first.
//
//        struct WireHeader @packed { char kind; uint length; ushort crc; }
//        // 7 bytes instead of 12
//
//    `@align(N)` — minimum alignment (it can only INCREASE it). On a
//    struct it's used for cache lines (64 bytes: so that two threads don't
//    fight over one line — "false sharing") and SIMD (16/32); on a field
//    it moves the field to an N-byte boundary:
//
//        struct Counter @align(64) { int value; }    // size 64, align 64
//
//    Combining `@packed @align(N)` gives you "tight inside, but aligned
//    outside".
//
//  FUNCTIONS
//
//    `@nodiscard` — the result must not be ignored. For functions where a
//    forgotten result is almost certainly a bug (an error code, a new value
//    instead of an in-place change). If you really must — `(void)f();`.
//    (Optional results can't be silently dropped anyway; `@maydiscard`
//    does the opposite and allows it.)
//
//    `@inline` / `@noinline` — always/never inline the function. They can
//    also be put on a specific call: `helper() @inline`. `@noinline` is
//    useful for "cold" code (error handling), so it doesn't bloat a hot
//    loop, and for profiling.
//
//    `@deprecated("message")` — any use produces a warning.
//
//    Other useful ones: `@noreturn` (the function never returns — `exit`),
//    `@unused` (don't warn about it being unused), `@cname("...")` /
//    `@export` (symbol name for C, see 092), `@weak`, `@section(...)`.
//    The full list is in MANUAL.md, section 6_13.
//
//  TASK:
//    1. `WireHeader` describes a 7-byte packet header. Add an attribute
//       so that the size check passes.
//    2. `SharedCounter` must take exactly one cache line (64 bytes) and
//       be aligned to 64.
//    3. The `data` field of `SimdBlock` must start at offset 16.
//    4. The line with `apply_damage` doesn't compile because of
//       `@nodiscard`. That's for a reason: the function does NOT change
//       hp, it returns the new value. Fix the call so the result is used.
//
import std::io;

struct WireHeader
{
    char kind;
    uint length;
    ushort crc;
}

struct SharedCounter
{
    int value;
}

struct SimdBlock
{
    char tag;
    float[4] data;
}

fn int apply_damage(int hp, int dmg) @nodiscard
{
    return hp > dmg ? hp - dmg : 0;
}

fn int cold_path(int code) @noinline
{
    return code * 1000;
}

fn void old_api() @deprecated("use apply_damage") {}

$assert WireHeader::size == 7 : "WireHeader must be 7 bytes";
$assert SharedCounter::size == 64 && SharedCounter::alignment == 64;
$assert $reflect(SimdBlock.data).offset == 16;

fn void main()
{
    io::printfn("WireHeader:    size=%d align=%d", WireHeader::size, WireHeader::alignment);
    io::printfn("SharedCounter: size=%d align=%d", SharedCounter::size, SharedCounter::alignment);
    io::printfn("SimdBlock:     size=%d, data at offset %d", SimdBlock::size, $reflect(SimdBlock.data).offset);

    WireHeader h = { 1, 512, 0xBEEF };
    // Fields of a packed struct are not aligned. You can't pass them to
    // printf directly (it receives `any` — a pointer to the field, and safe
    // mode will crash with "Unaligned access"). So we copy them into local
    // variables first: the compiler reads a field by value correctly.
    uint length = h.length;
    ushort crc = h.crc;
    io::printfn("header: kind=%d length=%d crc=%x", h.kind, length, crc);

    int hp = 100;
    apply_damage(hp, 30);
    assert(hp == 70);
    io::printfn("hp after hit: %d", hp);

    io::printfn("cold path: %d", cold_path(7));
}
