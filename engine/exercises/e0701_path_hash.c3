// =====================================================================
//  e0701 · Paths, hashes and ResourceId
// =====================================================================
//
//  Read engine/docs/07_resources.md first (sections
//  "Resource identity" and "Collisions").
//
//  An engine almost never stores or compares path strings at run time.
//  Instead of "textures/hero.png" it works with a 64-bit number —
//  ResourceId = FNV-1a(canonical path). A comparison is one instruction,
//  a hash-table key is 8 bytes, and the string itself is only needed for debugging.
//
//  But hashing paths has two pitfalls:
//
//  1. The same file can be written in different ways:
//         "Textures\\Hero.PNG", "./textures//hero.png",
//         "textures/old/../hero.png"
//     Hash them as-is and you get THREE different ids for one asset
//     and load it three times. So before hashing, the path is brought to
//     canonical form: '\' -> '/', lower case, empty segments and
//     "." are dropped, ".." removes the previous segment.
//
//  2. Collisions. Different paths can produce the same hash. With 64 bits this is
//     extremely unlikely but not impossible, and you want to find out in the TOOLS
//     (at registration/build time), not from a weird bug in a release. That is why
//     debug builds keep an id -> path registry and check every
//     insertion.
//
//  FNV-1a (64-bit):
//      h = 0xcbf29ce484222325
//      for each byte c:  h = (h ^ c) * 0x100000001b3
//  (multiplication is modulo 2^64 — in C3 unsigned overflow simply
//  "wraps around", as in C).
//
//  The hash of a string literal can be computed at compile time by a macro
//  using `$for` — then `@rid("sounds/jump.wav")` is just a constant,
//  and you can even use it in a `switch` `case`.
//
//  TASK (spots are marked TODO):
//    1. fnv1a64(data) — the runtime hash.
//    2. @rid($path) — the same hash at compile time (via $for).
//    3. normalize_path(path, out) — canonicalization by the rules above.
//    4. Registry.register(path) — normalize, hash and catch a
//       collision: same id but a DIFFERENT canonical path -> ID_COLLISION~.
//
import std::io;
import std::collections::map;

const ulong FNV_OFFSET = 0xcbf29ce484222325;
const ulong FNV_PRIME = 0x100000001b3;

typedef ResourceId = ulong;

excuse ID_COLLISION, PATH_TOO_LONG;

fn ulong fnv1a64(char[] data)
{
    // TODO: FNV-1a 64: start with FNV_OFFSET, for each byte h = (h ^ c) * FNV_PRIME
    return 0;
}

// Compile-time hash. The literal must ALREADY be canonical.
macro ulong @rid(String $path) @const
{
    // TODO: the same thing, but at compile time: `var $h = ...;` and `$for ... $endfor`.
    //       The macro's only runtime instruction is `return $h;`.
    return 0ul;
}

<*
 Writes the canonical path into out and returns a slice of out.
 Rules: '\' -> '/', A-Z -> a-z, empty and "." segments are skipped,
 ".." removes the previous segment (if any), segments are joined with '/'.
*>
fn String? normalize_path(String path, char[] out)
{
    // TODO: split path into segments on '/' and '\\', skip empty ones and ".",
    //       on ".." roll n back to the previous '/', append the remaining segments
    //       to out separated by '/', in lower case.
    //       If it does not fit in out -> return PATH_TOO_LONG~;
    if (path.len > out.len) return PATH_TOO_LONG~;
    out[:path.len] = path[..];
    return (String)out[:path.len];
}

fn ResourceId? path_id(String path)
{
    char[256] buf;
    String norm = normalize_path(path, &buf)!;
    return (ResourceId)fnv1a64(norm);
}

// ---------------------------------------------------------------------
// Registry id -> canonical path (lives in the tools / debug build).
// hash_bits lets you artificially "truncate" the hash to see
// collisions with your own eyes.
// ---------------------------------------------------------------------
struct Registry
{
    HashMap{ulong, String} names;   // owns copies of the strings
    ulong mask;
}

fn void Registry.init(&self, int hash_bits)
{
    self.names.init(mem);
    self.mask = hash_bits >= 64 ? ulong::max : (1ul << hash_bits) - 1;
}

fn void Registry.free(&self)
{
    self.names.@each(; ulong k, String v) { v.free(mem); };
    self.names.free();
}

fn ResourceId? Registry.register(&self, String path)
{
    char[256] buf;
    String norm = normalize_path(path, &buf)!;
    ulong id = fnv1a64(norm) & self.mask;
    // TODO: if id is already in self.names:
    //         - same canonical path -> just return id;
    //         - different path -> ID_COLLISION~.
    //       Otherwise store a COPY of the string (norm.copy(mem)) — buf dies
    //       when the function returns.
    return (ResourceId)id;
}

fn void main()
{
    // --- 1. runtime FNV-1a ---
    assert(fnv1a64("") == FNV_OFFSET, "empty string must hash to the offset basis");
    assert(fnv1a64("a") == 0xaf63dc4c8601ec8c, "fnv1a64(\"a\") is wrong");
    io::printfn("fnv(\"textures/hero.png\") = %x", fnv1a64("textures/hero.png"));

    // --- 2. compile-time id ---
    ulong jump = @rid("sounds/jump.wav");   // (an assert on a const is checked at compile time)
    assert(jump == fnv1a64("sounds/jump.wav"), "@rid must equal the runtime hash");
    assert(jump != 0, "@rid is not implemented");
    switch (fnv1a64("sounds/jump.wav"))
    {
        case @rid("sounds/jump.wav"): io::printn("switch on compile-time id: ok");
        default: unreachable("switch on @rid failed");
    }

    // --- 3. normalization ---
    char[256] buf;
    String[*] variants = {
        "textures/hero.png",
        "Textures\\Hero.PNG",
        "./textures//hero.png",
        "/textures/old/../hero.png",
        "textures/./a/b/../../hero.png",
    };
    foreach (v : variants)
    {
        String n = normalize_path(v, &buf)!!;
        io::printfn("%-32s -> %s", v, n);
        assert(n == "textures/hero.png", "bad normalization of '%s': '%s'", v, n);
        assert(path_id(v)!! == (ResourceId)fnv1a64("textures/hero.png"));
    }
    assert(normalize_path("../../x", &buf)!! == "x");
    assert(normalize_path("", &buf)!! == "");
    char[4] tiny;
    assert(@catch(normalize_path("models/tree.mesh", &tiny)) == PATH_TOO_LONG,
           "overflow of the output buffer must be reported");

    // --- 4. registry with full 64-bit ids: no collisions expected ---
    Registry full;
    full.init(64);
    defer full.free();
    ResourceId a = full.register("textures/hero.png")!!;
    ResourceId b = full.register("TEXTURES\\hero.png")!!;   // same asset
    assert(a == b, "same asset must give the same id");
    assert(full.names.len() == 1);

    // --- 5. registry with 16-bit ids: birthday paradox in action ---
    Registry small;
    small.init(16);
    defer small.free();
    int collisions = 0;
    for (int i = 0; i < 1000; i++)
    {
        String p = string::tformat("levels/l%d/asset_%d.tex", i % 7, i);
        if (catch err = small.register(p))
        {
            assert(err == ID_COLLISION);
            collisions++;
        }
    }
    io::printfn("16-bit ids, 1000 paths: %d collisions", collisions);
    assert(collisions > 0, "with 16-bit ids collisions are expected - register must detect them");
    io::printn("all path/hash tests passed");
}
