// =====================================================================
//  e1305 · Загрузка ассета «на месте»: смещения, fixup, relative pointers
// =====================================================================
//
//  Сначала прочитайте engine/docs/13_serialization.md (раздел 13.9).
//
//  Самый быстрый способ загрузить ассет — не разбирать его вовсе.
//  Инструмент (asset cooker) раскладывает меш в ОДИН непрерывный блоб:
//  заголовок, массив вершин, индексы, подмеши, строки. Вместо указателей
//  в блобе лежат смещения от его начала. Рантайм читает файл одним
//  вызовом в одну выровненную аллокацию и выполняет fixup: проходит по
//  известным полям-указателям и заменяет `offset` на `base + offset`.
//
//      union BlobPtr { ulong offset; void* ptr; }   // 8 байт в обоих видах
//
//  Перед fixup блоб, пришедший с диска, надо ПРОВЕРИТЬ: каждое
//  смещение плюс размер массива должно лежать внутри блоба и быть
//  выровненным под тип элемента. Иначе испорченный (или подделанный)
//  файл заставит нас читать чужую память.
//
//  Обратная операция — unfixup (указатели обратно в смещения) — нужна,
//  чтобы записать блоб на диск или переместить его в памяти (например,
//  при дефрагментации пула ассетов): абсолютные указатели после memmove
//  смотрят в СТАРЫЙ буфер.
//
//  Альтернатива — самоотносительные указатели (RelPtr): поле хранит
//  смещение цели от адреса САМОГО поля:
//      target = (char*)&field + field.off
//  Такой блоб можно копировать куда угодно целиком, fixup не нужен.
//
//  ЗАДАЧА (места с TODO):
//    1. validate  — проверить заголовок и все смещения (включая имена
//                   материалов в подмешах) до fixup;
//    2. MeshHeader.fixup и MeshHeader.unfixup;
//    3. RelPtr.get и RelPtr.set.
//
import std::io;

excuse BAD_MAGIC, BAD_OFFSET;

macro uint @fourcc(String $s) => $s[0] | $s[1] << 8 | $s[2] << 16 | $s[3] << 24;
const uint MESH_MAGIC = @fourcc("MESH");

union BlobPtr
{
    ulong offset;
    void* ptr;
}

struct Vertex
{
    float x, y, z;
    uint color;
}

struct Submesh
{
    uint first_index;
    uint index_count;
    BlobPtr material;        // char*, строка с завершающим 0
    ulong material_len;
}

struct MeshHeader
{
    uint magic;
    uint vertex_count;
    uint index_count;
    uint submesh_count;
    BlobPtr name;            // char*
    ulong name_len;
    BlobPtr vertices;        // Vertex*
    BlobPtr indices;         // ushort*
    BlobPtr submeshes;       // Submesh*
}

// Раскладка — часть формата: страхуемся на этапе компиляции.
$assert MeshHeader::size == 56;
$assert Submesh::size == 24;
$assert Vertex::size == 16;

fn String MeshHeader.get_name(&self) => (String)((char*)self.name.ptr)[:self.name_len];
fn Vertex[] MeshHeader.get_vertices(&self) => ((Vertex*)self.vertices.ptr)[:self.vertex_count];
fn ushort[] MeshHeader.get_indices(&self) => ((ushort*)self.indices.ptr)[:self.index_count];
fn Submesh[] MeshHeader.get_submeshes(&self) => ((Submesh*)self.submeshes.ptr)[:self.submesh_count];
fn String Submesh.get_material(&self) => (String)((char*)self.material.ptr)[:self.material_len];

// ------------------------------------------------------------ «cooker» (готово)

const usz BLOB_CAP = 512;

struct BlobBuilder
{
    char* base;
    usz len;
}

fn usz BlobBuilder.alloc(&self, usz size, usz align)
{
    self.len = (self.len + align - 1) / align * align;
    usz at = self.len;
    self.len += size;
    assert(self.len <= BLOB_CAP);
    return at;
}

fn usz BlobBuilder.add_string(&self, String s)
{
    usz at = self.alloc(s.len + 1, 1);
    for (usz i = 0; i < s.len; i++) self.base[at + i] = s[i];
    self.base[at + s.len] = 0;
    return at;
}

fn usz cook_mesh(char* base)
{
    BlobBuilder b = { .base = base };
    usz h_at = b.alloc(MeshHeader::size, MeshHeader::alignment);
    MeshHeader* h = (MeshHeader*)(base + h_at);
    *h = { .magic = MESH_MAGIC, .vertex_count = 4, .index_count = 6, .submesh_count = 2 };

    h.vertices.offset = b.alloc(Vertex::size * 4, Vertex::alignment);
    Vertex* v = (Vertex*)(base + h.vertices.offset);
    v[0] = { -1, -1, 0, 0xFF0000FF };
    v[1] = {  1, -1, 0, 0xFF00FF00 };
    v[2] = {  1,  1, 0, 0xFFFF0000 };
    v[3] = { -1,  1, 0, 0xFFFFFFFF };

    h.indices.offset = b.alloc(ushort::size * 6, ushort::alignment);
    ushort* idx = (ushort*)(base + h.indices.offset);
    idx[:6] = (ushort[6]){ 0, 1, 2, 2, 3, 0 }[..];

    h.submeshes.offset = b.alloc(Submesh::size * 2, Submesh::alignment);
    Submesh* sm = (Submesh*)(base + h.submeshes.offset);
    sm[0] = { .first_index = 0, .index_count = 3, .material_len = 5 };
    sm[1] = { .first_index = 3, .index_count = 3, .material_len = 5 };

    h.name.offset = b.add_string("quad");
    h.name_len = 4;
    sm[0].material.offset = b.add_string("stone");
    sm[1].material.offset = b.add_string("moss1");
    return b.len;
}

// ------------------------------------------------------------ загрузка

// true, если массив из `count` элементов размера `elem` по смещению `off`
// целиком лежит в блобе длины `len` и смещение кратно `align`.
fn bool range_ok(ulong off, ulong count, ulong elem, ulong align, usz len)
{
    if (off % align != 0) return false;
    if (off > len) return false;
    return count <= (len - off) / elem;   // без переполнения off + count * elem
}

fn void? validate(char[] blob)
{
    if (blob.len < MeshHeader::size) return BAD_OFFSET~;
    MeshHeader* h = (MeshHeader*)blob.ptr;
    // TODO: magic -> BAD_MAGIC~;
    //   name (len + 1 байт на 0), vertices, indices, submeshes — через range_ok, иначе BAD_OFFSET~;
    //   затем для каждого подмеша (смещения ещё НЕ исправлены, адрес считаем вручную:
    //   (Submesh*)(blob.ptr + h.submeshes.offset)) проверить material и что
    //   first_index + index_count <= h.index_count.
    return;
}

fn void MeshHeader.fixup(&self, char* base)
{
    // TODO: превратить все BlobPtr (name, vertices, indices, submeshes и
    //       material каждого подмеша) из смещений в указатели base + offset.
}

fn void MeshHeader.unfixup(&self, char* base)
{
    // TODO: обратная операция: offset = ptr - base. Порядок важен: пока
    //       submeshes ещё указатель, сначала обработайте материалы подмешей.
}

// ------------------------------------------------------------ self-relative pointers

struct RelPtr
{
    int off;      // от адреса этого поля до цели; 0 = null
}

fn void* RelPtr.get(&self)
{
    // TODO: null при off == 0, иначе (char*)self + off
    return null;
}

fn void RelPtr.set(&self, void* target)
{
    // TODO: off = target - адрес поля (null -> 0)
}

struct DialogLine
{
    RelPtr text;      // char*
    RelPtr next;      // DialogLine*
    int text_len;
    int speaker;
}

fn String DialogLine.get_text(&self) => (String)((char*)self.text.get())[:self.text_len];

fn void cook_dialog(char* base)
{
    BlobBuilder b = { .base = base };
    String[3] texts = { "Halt!", "Who goes there?", "A friend." };
    DialogLine* prev = null;
    foreach (i, t : texts)
    {
        DialogLine* line = (DialogLine*)(base + b.alloc(DialogLine::size, DialogLine::alignment));
        line.text.set(base + b.add_string(t));
        line.text_len = (int)t.len;
        line.speaker = (int)i % 2;
        line.next.set(null);
        if (prev) prev.next.set(line);
        prev = line;
    }
}

fn int print_dialog(DialogLine* first)
{
    int n;
    for (DialogLine* l = first; l; l = l.next.get())
    {
        io::printfn("  [%d] %s", l.speaker, l.get_text());
        n++;
    }
    return n;
}

// ------------------------------------------------------------ тесты

fn void hexdump(char[] bytes)
{
    foreach (i, b : bytes)
    {
        io::printf("%02x", b);
        io::print((i % 16 == 15 || i + 1 == bytes.len) ? "\n" : " ");
    }
}

macro void @expect_err(String what, #expr)
{
    if (catch e = #expr)
    {
        io::printfn("%s: %s", what, e);
        return;
    }
    unreachable("expected an error: %s", what);
}

fn void main()
{
    ulong[BLOB_CAP / 8] disk_storage;       // ulong — ради выравнивания 8
    char* disk = (char*)&disk_storage;
    usz len = cook_mesh(disk);
    io::printfn("cooked mesh blob: %d bytes, header:", len);
    hexdump(disk[:MeshHeader::size]);

    // «Чтение файла»: одна копия в одну выровненную аллокацию.
    ulong[BLOB_CAP / 8] mem_storage;
    char* blob = (char*)&mem_storage;
    blob[:len] = disk[:len];

    validate(blob[:len])!!;
    MeshHeader* h = (MeshHeader*)blob;
    h.fixup(blob);
    assert((char*)h.name.ptr >= blob && (char*)h.name.ptr < blob + len, "fixup must turn offsets into pointers into the blob");
    assert((char*)h.get_submeshes()[1].material.ptr == blob + 195, "submesh materials need fixup too");

    assert(h.get_name() == "quad");
    Vertex[] verts = h.get_vertices();
    assert(verts.len == 4 && verts[2].x == 1 && verts[3].color == 0xFFFFFFFF);
    assert((char*)verts.ptr == blob + MeshHeader::size, "pointers must point into the loaded blob");
    io::printfn("mesh '%s': %d vertices, %d indices", h.get_name(), verts.len, h.get_indices().len);
    foreach (sm : h.get_submeshes())
    {
        io::printf("  submesh %-6s:", sm.get_material());
        foreach (i : h.get_indices()[sm.first_index:sm.index_count])
        {
            io::printf(" (%.0f,%.0f)", verts[i].x, verts[i].y);
        }
        io::printn();
    }

    // unfixup возвращает блоб в точности к виду на диске.
    h.unfixup(blob);
    assert(blob[:len] == disk[:len], "unfixup must restore the on-disk bytes");
    io::printn("unfixup restores disk image: yes");

    // --- испорченные файлы ---
    ulong[BLOB_CAP / 8] bad_storage;
    char* bad = (char*)&bad_storage;
    bad[:len] = disk[:len];
    ((MeshHeader*)bad).magic = 0;
    @expect_err("wrong magic", validate(bad[:len]));
    bad[:len] = disk[:len];
    ((MeshHeader*)bad).vertex_count = 1000;
    @expect_err("too many vertices", validate(bad[:len]));
    bad[:len] = disk[:len];
    ((MeshHeader*)bad).indices.offset += 1;
    @expect_err("misaligned indices", validate(bad[:len]));
    bad[:len] = disk[:len];
    ((MeshHeader*)bad).submeshes.offset = ulong::max - 8;
    @expect_err("huge offset", validate(bad[:len]));
    bad[:len] = disk[:len];
    ((Submesh*)(bad + ((MeshHeader*)bad).submeshes.offset))[1].material.offset = len;
    @expect_err("material past the end", validate(bad[:len]));
    bad[:len] = disk[:len];
    ((Submesh*)(bad + ((MeshHeader*)bad).submeshes.offset))[1].index_count = 4;
    @expect_err("submesh index range", validate(bad[:len]));
    @expect_err("truncated", validate(disk[:40]));

    // --- self-relative: блоб можно переносить без fixup ---
    ulong[32] a_storage;
    ulong[32] b_storage;
    char* a = (char*)&a_storage;
    char* b = (char*)&b_storage;
    cook_dialog(a);
    DialogLine* first = (DialogLine*)a;
    assert(first.text.off == DialogLine::size, "string \"Halt!\" is cooked right after line 0");
    io::printn("dialog (original):");
    assert(print_dialog(first) == 3);
    b[:256] = a[:256];
    a[:256] = (char[256]){}[..];             // старый буфер стёрт
    io::printn("dialog (moved, no fixup):");
    assert(print_dialog((DialogLine*)b) == 3);
    io::printn("blob fixup ok");
}
