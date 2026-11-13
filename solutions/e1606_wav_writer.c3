// =====================================================================
//  e1606 · Пишем WAV-файл
// =====================================================================
//
//  WAV — самый простой контейнер для PCM: заголовок RIFF и сырые
//  сэмплы. Его умеет открыть любой плеер и аудиоредактор, поэтому
//  «сбросить микс в .wav» — лучший отладочный инструмент аудиодвижка:
//  записали выход микшера, открыли в Audacity — и ГЛАЗАМИ видно щелчки,
//  клиппинг, сдвиги фазы.
//
//  Каноничный 44-байтный заголовок (все числа — little-endian):
//
//    off  size  поле
//     0    4    "RIFF"
//     4    4    riff_size = 36 + data_size   (размер файла - 8)
//     8    4    "WAVE"
//    12    4    "fmt "                       (с пробелом!)
//    16    4    16                           (размер fmt-чанка)
//    20    2    1                            (формат: 1 = PCM целые)
//    22    2    channels
//    24    4    sample_rate
//    28    4    byte_rate   = sample_rate * block_align
//    32    2    block_align = channels * bits / 8   (байт на кадр)
//    34    2    bits_per_sample (16)
//    36    4    "data"
//    40    4    data_size   = frames * block_align
//    44    ...  сэмплы, перемежённые (L R L R ...)
//
//  Little-endian значит: младший байт первым. 0x12345678 записывается
//  как 78 56 34 12. Не пишите структуру в файл целиком через memcpy:
//  порядок байт и выравнивание полей зависят от платформы и компилятора.
//  Пишите поле за полем — это и есть «сериализация» (глава 13).
//
//  ЗАДАЧА: реализуйте put_u16/put_u32 (little-endian), build_wav
//  (заголовок + данные) и parse_wav (разбор заголовка обратно).
//  Программа запишет tone.wav в текущий каталог, прочитает его и
//  сверит. Решив упражнение, можете открыть .build/tone.wav в плеере.
//
import std::io, std::io::file;

const usz HEADER_SIZE = 44;

struct WavInfo
{
    int channels;
    int sample_rate;
    int bits;
    int frames;
}

fn void put_u16(char[] buf, usz off, ushort v)
{
    buf[off] = (char)(v & 0xFF);
    buf[off + 1] = (char)(v >> 8);
}

fn void put_u32(char[] buf, usz off, uint v)
{
    for (usz i = 0; i < 4; i++) buf[off + i] = (char)((v >> (8 * i)) & 0xFF);
}

fn uint get_u32(char[] buf, usz off)
{
    return buf[off] | (uint)buf[off + 1] << 8 | (uint)buf[off + 2] << 16 | (uint)buf[off + 3] << 24;
}

fn ushort get_u16(char[] buf, usz off) => (ushort)(buf[off] | (ushort)buf[off + 1] << 8);

fn void put_tag(char[] buf, usz off, String tag)
{
    foreach (usz i, ch : tag) buf[off + i] = ch;
}

// Заполнить out (длиной HEADER_SIZE + samples.len * 2) заголовком и
// 16-битными сэмплами. samples — уже перемежённые.
fn void build_wav(char[] out, short[] samples, int channels, int sample_rate)
{
    assert(out.len == HEADER_SIZE + samples.len * 2);
    uint data_size = (uint)samples.len * 2;
    ushort block_align = (ushort)(channels * 2);
    put_tag(out, 0, "RIFF");
    put_u32(out, 4, 36 + data_size);
    put_tag(out, 8, "WAVE");
    put_tag(out, 12, "fmt ");
    put_u32(out, 16, 16);
    put_u16(out, 20, 1);
    put_u16(out, 22, (ushort)channels);
    put_u32(out, 24, (uint)sample_rate);
    put_u32(out, 28, (uint)sample_rate * block_align);
    put_u16(out, 32, block_align);
    put_u16(out, 34, 16);
    put_tag(out, 36, "data");
    put_u32(out, 40, data_size);
    foreach (usz i, s : samples) put_u16(out, HEADER_SIZE + 2 * i, (ushort)s);
}

fn bool tag_is(char[] buf, usz off, String tag) => (String)buf[off:4] == tag;

// Разобрать заголовок. Вернуть false, если это не 16-битный PCM WAV
// или размеры не сходятся с длиной файла.
fn bool parse_wav(char[] data, WavInfo* info)
{
    if (data.len < HEADER_SIZE) return false;
    if (!tag_is(data, 0, "RIFF") || !tag_is(data, 8, "WAVE")) return false;
    if (!tag_is(data, 12, "fmt ") || !tag_is(data, 36, "data")) return false;
    if (get_u16(data, 20) != 1 || get_u16(data, 34) != 16) return false;
    uint data_size = get_u32(data, 40);
    if (get_u32(data, 4) != 36 + data_size) return false;
    if (HEADER_SIZE + (usz)data_size != data.len) return false;
    info.channels = get_u16(data, 22);
    info.sample_rate = (int)get_u32(data, 24);
    info.bits = 16;
    info.frames = (int)data_size / (info.channels * 2);
    return true;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

fn uint fnv1a(char[] data)
{
    uint h = 2166136261;
    foreach (b : data) h = (h ^ b) * 16777619;
    return h;
}

fn void main()
{
    char[4] t;
    put_u32(&t, 0, 0x12345678);
    assert(t[0] == 0x78 && t[3] == 0x12, "little-endian: младший байт первым");
    put_u16(&t, 0, 0xBEEF);
    assert(t[0] == 0xEF && t[1] == 0xBE);

    // полсекунды стерео 8 кГц: слева «пила» 250 Гц, справа квадрат 125 Гц
    const RATE = 8000;
    const FRAMES = RATE / 2;
    short[] pcm = mem::new_array(short, FRAMES * 2);
    defer free(pcm);
    for (int i = 0; i < FRAMES; i++)
    {
        pcm[2 * i] = (short)((i % 32) * 2000 - 31000);
        pcm[2 * i + 1] = (i / 32) % 2 == 0 ? (short)12000 : (short)-12000;
    }

    char[] wav = mem::new_array(char, HEADER_SIZE + pcm.len * 2);
    defer free(wav);
    build_wav(wav, pcm, 2, RATE);
    file::save("tone.wav", wav)!!;

    char[] back = file::load(mem, "tone.wav")!!;
    defer free(back);
    WavInfo info;
    assert(parse_wav(back, &info), "файл не разобрался");
    assert(info.channels == 2 && info.sample_rate == RATE && info.frames == FRAMES);
    assert((short)get_u16(back, HEADER_SIZE + 2) == 12000, "первый правый сэмпл");
    char[] broken = back[:HEADER_SIZE + 10];
    assert(!parse_wav(broken, &info), "обрезанный файл должен отвергаться");

    io::printfn("tone.wav: %d bytes, %d ch, %d Hz, %d frames", back.len, 2, RATE, FRAMES);
    io::printfn("byte_rate=%d block_align=%d", get_u32(back, 28), get_u16(back, 32));
    io::printfn("fnv1a=%08x", fnv1a(back));
}
