// =====================================================================
//  e1602 · Микшер: сложение голосов, громкость, панорама, headroom
// =====================================================================
//
//  Микшер — сердце аудиодвижка. Каждый «голос» (voice) — это
//  проигрываемый звук: ссылка на сэмплы + позиция + громкость + панорама.
//  Каждый аудиоблок (обычно 256–1024 кадра) микшер делает одно и то же:
//
//      out[] = 0
//      для каждого активного голоса:
//          out[] += samples[pos..] * gain * (gl | gr)
//      master: out[] *= master_gain; clip; -> int16 -> устройство
//
//  Микширование — это просто СЛОЖЕНИЕ. Два звука громкостью 0.8 дают
//  1.6 — больше, чем допускает выход. Отсюда две техники:
//
//    * headroom — запас: мастер-громкость < 1 (например, 0.5 = -6 dB),
//      чтобы сумма типичного числа голосов не выходила за ±1;
//    * клиппинг на выходе — последняя линия обороны. Жёсткий (hard clip)
//      просто режет по ±1 (звучит как треск), мягкий (soft clip)
//      плавно «сжимает» пики. В движках вместо него обычно стоит
//      лимитер на мастер-шине, но идея та же.
//
//  Панорама (pan ∈ [-1, 1]) распределяет моно-звук между каналами.
//  Наивный закон gl = (1-pan)/2, gr = (1+pan)/2 даёт провал громкости
//  в центре (0.5 + 0.5 по амплитуде ≈ -3 dB по мощности). Поэтому
//  используют закон постоянной мощности (constant power):
//
//      angle = (pan + 1) * PI / 4          // 0 .. PI/2
//      gl = cos(angle), gr = sin(angle)    // gl^2 + gr^2 == 1
//
//  ЗАДАЧА: реализуйте
//    pan_gains   — закон постоянной мощности;
//    mix_voice   — прибавить голос в перемежённый стерео-буфер; голос
//                  продвигается; в конце звука либо зацикливается
//                  (looping), либо становится неактивным;
//    hard_clip, soft_clip, to_s16_master — выходной каскад.
//
import std::io, std::math;

struct Voice
{
    float[] samples;   // моно-сэмплы звука
    usz pos;           // следующий сэмпл для чтения
    float gain;
    float pan;
    bool looping;
    bool active;
}

fn void pan_gains(float pan, float* gl, float* gr)
{
    float angle = (pan + 1.0f) * (float)math::PI / 4.0f;
    *gl = math::cos(angle);
    *gr = math::sin(angle);
}

// out — перемежённый стерео-буфер (L R L R ...), к нему ПРИБАВЛЯЕМ.
fn void mix_voice(Voice* v, float[] out)
{
    if (!v.active) return;
    float gl;
    float gr;
    pan_gains(v.pan, &gl, &gr);
    usz frames = out.len / 2;
    for (usz f = 0; f < frames; f++)
    {
        if (v.pos >= v.samples.len)
        {
            if (!v.looping) { v.active = false; return; }
            v.pos = 0;
        }
        float s = v.samples[v.pos++] * v.gain;
        out[2 * f] += s * gl;
        out[2 * f + 1] += s * gr;
    }
}

fn float hard_clip(float x)
{
    return x > 1.0f ? 1.0f : (x < -1.0f ? -1.0f : x);
}

// Кубический мягкий клиппер: для |x| <= 1: 1.5x - 0.5x^3, иначе ±1.
// Он гладкий в точке ±1 (производная там 0) и почти линеен около нуля.
fn float soft_clip(float x)
{
    if (x >= 1.0f) return 1.0f;
    if (x <= -1.0f) return -1.0f;
    return 1.5f * x - 0.5f * x * x * x;
}

// Мастер-каскад: умножить на master, обрезать (hard или soft), перевести
// в int16 (x * 32767 с округлением к ближайшему). Возвращает число
// сэмплов, которые ПОСЛЕ умножения на master выходили за ±1.
fn int to_s16_master(float[] mix, float master, bool soft, short[] out)
{
    int clipped = 0;
    foreach (i, x : mix)
    {
        float y = x * master;
        if (y > 1.0f || y < -1.0f) clipped++;
        y = soft ? soft_clip(y) : hard_clip(y);
        float s = y * 32767.0f;
        out[i] = (short)(s >= 0 ? s + 0.5f : s - 0.5f);
    }
    return clipped;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

fn uint fnv1a_s16(short[] data)
{
    uint h = 2166136261;
    foreach (s : data)
    {
        ushort u = (ushort)s;
        h = (h ^ (u & 0xFF)) * 16777619;
        h = (h ^ (u >> 8)) * 16777619;
    }
    return h;
}

fn bool near(float a, float b) => math::abs(a - b) < 0.0005f;

fn void main()
{
    // панорама
    float gl;
    float gr;
    pan_gains(0.0f, &gl, &gr);
    assert(near(gl, 0.70711f) && near(gr, 0.70711f), "центр: оба канала ~0.7071");
    pan_gains(-1.0f, &gl, &gr);
    assert(near(gl, 1.0f) && near(gr, 0.0f), "pan=-1: только левый");
    for (int i = -4; i <= 4; i++)
    {
        pan_gains(i / 4.0f, &gl, &gr);
        assert(near(gl * gl + gr * gr, 1.0f), "мощность должна быть постоянной");
    }
    io::printn("pan: ok");

    // звуки: квадратная волна, «пила» и короткий щелчок
    float[40] square;
    float[25] saw;
    float[6] click = { 1.0f, -1.0f, 0.5f, -0.5f, 0.25f, -0.25f };
    foreach (i, &s : square) *s = (i / 5) % 2 == 0 ? 0.6f : -0.6f;
    foreach (i, &s : saw) *s = -1.0f + 2.0f * (float)i / 25.0f;

    Voice[3] voices = {
        { .samples = &square, .gain = 1.0f, .pan = 0.0f, .looping = true, .active = true },
        { .samples = &saw, .gain = 0.8f, .pan = -0.5f, .looping = true, .active = true },
        { .samples = &click, .gain = 1.0f, .pan = 1.0f, .looping = false, .active = true },
    };

    const FRAMES = 64;
    float[FRAMES * 2] mix;
    foreach (&v : voices) mix_voice(v, &mix);
    assert(!voices[2].active, "щелчок закончился и должен стать неактивным");
    assert(voices[0].active && voices[0].pos == 64 % 40, "зацикленный голос продолжает с начала");
    assert(voices[1].pos == 64 % 25);
    assert(near(mix[1], 0.6f * 0.70711f + -0.8f * 0.38268f + 1.0f), "кадр 0, правый канал");

    short[FRAMES * 2] pcm;
    int c_full = to_s16_master(&mix, 1.0f, false, &pcm);
    uint h_hard = fnv1a_s16(&pcm);
    int c_soft = to_s16_master(&mix, 1.0f, true, &pcm);
    uint h_soft = fnv1a_s16(&pcm);
    int c_room = to_s16_master(&mix, 0.5f, false, &pcm);
    assert(c_full > 0 && c_room == 0, "с запасом -6 dB клиппинга быть не должно");
    assert(soft_clip(0.5f) == 0.6875f && soft_clip(2.0f) == 1.0f);
    io::printfn("clipped: master=1.0 -> %d, master=0.5 -> %d", c_full, c_room);
    io::printfn("soft clipped count: %d", c_soft);
    io::printfn("pcm[0..4] with headroom: %d %d %d %d", pcm[0], pcm[1], pcm[2], pcm[3]);
    io::printfn("hard != soft: %s", h_hard != h_soft);
}
