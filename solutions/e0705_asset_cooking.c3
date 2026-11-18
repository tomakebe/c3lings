// =====================================================================
//  e0705 · Offline pipeline: "cooking" an asset into a binary format
// =====================================================================
//
//  Read engine/docs/07_resources.md first (section "Asset
//  pipeline: source -> cooked").
//
//  Source assets (FBX, PNG, JSON, text configs) are convenient for people and
//  DCC tools but bad for the runtime: they must be parsed, validated,
//  converted. So engines "cook" them OFFLINE — in
//  the tools or on a build farm — into a binary format that the runtime
//  loads with almost no work: read a block of bytes, check the header,
//  point pointers straight into the loaded buffer ("in-place loading").
//
//  Our mesh format (all numbers little-endian):
//
//      offset size  field
//      0      4     magic    = 'M','S','H','1'
//      4      2     version  = FORMAT_VERSION
//      6      2     flags    (0 for now)
//      8      4     vertex_count
//      12     4     index_count
//      16     4     payload_size   (bytes after the header)
//      20     4     checksum       FNV-1a 32 of the payload
//      24     ...   payload: vertex_count * 3 float, then index_count
//                   ushort, then zeros up to a multiple of 4
//
//  The 24-byte header is a multiple of 4, so the floats in the payload are aligned, and
//  the runtime can view them as a float[] without copying.
//
//  Principle: all expensive validation (indices in range, limits) happens at
//  cook time. The runtime checks only what is cheap and catches real
//  problems: magic, version (format changed — rebuild the assets!),
//  size (file truncated) and checksum (file corrupted).
//
//  Numbers are written byte by byte, explicitly little-endian, rather than `memcpy`ing a struct:
//  that way the format does not depend on the compiler (padding) or platform.
//
//  TASK (TODO below):
//    1. put_u16 / put_u32 / put_f32 — little-endian writes.
//    2. cook(src, out) — validate the source (INVALID_SOURCE~ on an index
//       out of range or an index count not divisible by 3) and write the file.
//    3. load(blob) — check the header and return a Mesh with slices
//       pointing straight into blob.
//
import std::io;
import std::collections::list;

excuse INVALID_SOURCE, BAD_MAGIC, BAD_VERSION, TRUNCATED, CORRUPT;

const ushort FORMAT_VERSION = 3;
const usz HEADER_SIZE = 24;
const char[4] MAGIC = { 'M', 'S', 'H', '1' };

fn uint fnv1a32(char[] data)
{
    uint h = 2166136261;
    foreach (c : data) h = (h ^ c) * 16777619;
    return h;
}

// ---------------------------------------------------------------------
// The "source" format is text. Parsing is provided.
// ---------------------------------------------------------------------
struct SourceMesh
{
    List{float} positions;   // x y z x y z ...
    List{int} indices;
}

// NOTE: a List without init() takes the TEMPORARY allocator on the first push
// (tmem). Inside @pool() that means "the data disappears when the pool
// exits". So everything that must live longer is explicitly initialized with mem.
fn void SourceMesh.init(&self)
{
    self.positions.init(mem);
    self.indices.init(mem);
}

fn void SourceMesh.free(&self)
{
    self.positions.free();
    self.indices.free();
}

fn void? parse_source(String text, SourceMesh* out) => @pool()
{
    foreach (raw : text.tsplit("\n"))
    {
        String line = raw.trim();
        if (line.len == 0 || line[0] == '#') continue;
        String[] w = line.tsplit(" ");
        if (w[0] == "vertex" && w.len == 4)
        {
            for (int i = 1; i < 4; i++) out.positions.push(w[i].to_float()!);
        }
        else if (w[0] == "tri" && w.len == 4)
        {
            for (int i = 1; i < 4; i++) out.indices.push(w[i].to_int()!);
        }
        else
        {
            return INVALID_SOURCE~;
        }
    }
}

// ---------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------
fn void put_u8(List{char}* out, char v) => out.push(v);

fn void put_u16(List{char}* out, ushort v)
{
    out.push((char)(v & 0xFF));
    out.push((char)(v >> 8));
}

fn void put_u32(List{char}* out, uint v)
{
    for (int i = 0; i < 4; i++) out.push((char)(v >> (8 * i)));
}

fn void put_f32(List{char}* out, float v) => put_u32(out, bitcast(v, uint));

fn void? cook(SourceMesh* src, List{char}* out)
{
    usz vcount = (usz)src.positions.len() / 3;   // List.len() is a signed sz!
    usz icount = (usz)src.indices.len();
    if (icount % 3 != 0 || vcount > 65535) return INVALID_SOURCE~;
    foreach (i : src.indices)
    {
        if (i < 0 || (usz)i >= vcount) return INVALID_SOURCE~;
    }

    // payload is built separately to compute its size and checksum
    List{char} payload;
    payload.init(mem);
    defer payload.free();
    foreach (f : src.positions) put_f32(&payload, f);
    foreach (i : src.indices) put_u16(&payload, (ushort)i);
    while (payload.len() % 4 != 0) put_u8(&payload, 0);

    foreach (c : MAGIC) put_u8(out, c);
    put_u16(out, FORMAT_VERSION);
    put_u16(out, 0);
    put_u32(out, (uint)vcount);
    put_u32(out, (uint)icount);
    put_u32(out, (uint)payload.len());
    put_u32(out, fnv1a32(payload.array_view()));
    out.push_all(payload.array_view());
}

// ---------------------------------------------------------------------
// Reading (runtime)
// ---------------------------------------------------------------------
fn ushort get_u16(char[] b, usz at) => (ushort)b[at] | (ushort)b[at + 1] << 8;
fn uint get_u32(char[] b, usz at)
    => (uint)b[at] | (uint)b[at + 1] << 8 | (uint)b[at + 2] << 16 | (uint)b[at + 3] << 24;

// The slices point straight into blob: zero-copy loading.
// (Casting bytes to float[] assumes a little-endian host — like x86/ARM.)
struct Mesh
{
    float[] positions;
    ushort[] indices;
}

fn Mesh? load(char[] blob)
{
    if (blob.len < HEADER_SIZE) return TRUNCATED~;
    if (blob[:4] != MAGIC[..]) return BAD_MAGIC~;
    if (get_u16(blob, 4) != FORMAT_VERSION) return BAD_VERSION~;
    uint vcount = get_u32(blob, 8);
    uint icount = get_u32(blob, 12);
    uint size = get_u32(blob, 16);
    if (blob.len < HEADER_SIZE + size) return TRUNCATED~;
    char[] payload = blob[HEADER_SIZE:size];
    if (fnv1a32(payload) != get_u32(blob, 20)) return CORRUPT~;
    if ((usz)vcount * 12 + (usz)icount * 2 > size) return CORRUPT~;
    return {
        .positions = ((float*)payload.ptr)[:vcount * 3],
        .indices = ((ushort*)(payload.ptr + vcount * 12))[:icount],
    };
}

// ---------------------------------------------------------------------

const String QUAD_SRC = `
# unit quad in the XY plane
vertex 0 0 0
vertex 1 0 0
vertex 1 1 0
vertex 0 1.5 -2
tri 0 1 2
tri 0 2 3
tri 3 2 1
`;

fn void dump(char[] b, usz n)
{
    for (usz i = 0; i < n; i++) io::printf("%02x%s", b[i], (i + 1) % 4 == 0 ? " " : "");
    io::printn();
}

fn void main()
{
    // put_* — little-endian
    List{char} t;
    t.init(mem);
    defer t.free();
    put_u16(&t, 0x1234);
    put_u32(&t, 0xAABBCCDD);
    put_f32(&t, 1.0f);
    char[*] want = { 0x34, 0x12, 0xDD, 0xCC, 0xBB, 0xAA, 0x00, 0x00, 0x80, 0x3F };
    assert(t.array_view() == want[..], "put_u16/put_u32/put_f32 must write little-endian bytes");

    SourceMesh src;
    src.init();
    defer src.free();
    parse_source(QUAD_SRC, &src)!!;

    List{char} blob;
    blob.init(mem);
    defer blob.free();
    cook(&src, &blob)!!;
    io::printfn("cooked: %d bytes (header %d + payload %d)", blob.len(), HEADER_SIZE, (usz)blob.len() - HEADER_SIZE);
    io::printf("header: ");
    dump(blob.array_view(), HEADER_SIZE);
    assert((usz)blob.len() == HEADER_SIZE + 4 * 12 + 20, "size = header + 48 bytes of floats + 18 bytes of indices + 2 pad");

    Mesh m = load(blob.array_view())!!;
    assert(m.positions.len == 12 && m.indices.len == 9);
    assert(m.positions[10] == 1.5f && m.positions[11] == -2.0f);
    assert(m.indices[6] == 3 && m.indices[8] == 1);
    assert((char*)m.positions.ptr == blob.entries + HEADER_SIZE, "load must not copy - slices point into the blob");
    io::printfn("loaded: %d vertices, %d triangles", m.positions.len / 3, m.indices.len / 3);

    // --- runtime checks ---
    char[] b = blob.array_view();
    assert(@catch(load(b[:10])) == TRUNCATED);
    assert(@catch(load(b[:b.len - 4])) == TRUNCATED, "payload shorter than payload_size");
    b[30] ^= 0x01;
    assert(@catch(load(b)) == CORRUPT, "flipped bit in payload must be detected");
    b[30] ^= 0x01;
    b[4] = (char)(FORMAT_VERSION - 1);
    assert(@catch(load(b)) == BAD_VERSION, "old asset version must be rejected");
    b[4] = (char)FORMAT_VERSION;
    b[0] = 'X';
    assert(@catch(load(b)) == BAD_MAGIC);
    b[0] = 'M';
    (void)load(b)!!;

    // --- cook-time checks ---
    SourceMesh bad;
    bad.init();
    defer bad.free();
    parse_source("vertex 0 0 0\nvertex 1 0 0\ntri 0 1 2\n", &bad)!!;
    List{char} dummy;
    dummy.init(mem);
    defer dummy.free();
    assert(@catch(cook(&bad, &dummy)) == INVALID_SOURCE, "index 2 is out of range: cooking must fail");
    io::printfn("checksum %08x", get_u32(blob.array_view(), 20));
    io::printn("cook/load round trip ok");
}
