// =====================================================================
//  e1604 · Ресэмплинг, фильтр нижних частот и огибающая ADSR
// =====================================================================
//
//  1) РЕСЭМПЛИНГ. Звук записан на 22050 Гц, устройство хочет 48000 Гц;
//  или игра меняет высоту тона (pitch) — проигрывает звук быстрее.
//  И то и другое — чтение исходника с ДРОБНЫМ шагом:
//
//      step = src_rate / dst_rate * pitch
//      pos:   0    0.46   0.92   1.38 ...
//      src:  [a0]-------[a1]-------[a2]
//      out = a[i] + (a[i+1] - a[i]) * frac        (линейная интерполяция)
//
//  Позицию удобно хранить в фиксированной точке 16.16: старшие биты —
//  индекс, младшие 16 — дробь (0..65535). Так нет накопления ошибки
//  float на длинных звуках и всё строго детерминировано. Линейная
//  интерполяция — дешёвый компромисс: качественные ресэмплеры
//  (windowed sinc, polyphase) подавляют алиасинг лучше, но дороже.
//
//  2) ОДНОПОЛЮСНЫЙ ФИЛЬТР НИЖНИХ ЧАСТОТ (one-pole low-pass):
//
//      y[n] = y[n-1] + a * (x[n] - y[n-1]),   0 < a <= 1
//
//  Это «экспоненциальное сглаживание»: чем меньше a, тем ниже частота
//  среза и «глуше» звук (звук за стеной, под водой). У фильтра есть
//  СОСТОЯНИЕ (y[n-1]) — оно должно жить между аудиоблоками, иначе на
//  границе блока будет щелчок.
//
//  3) ОГИБАЮЩАЯ ADSR управляет громкостью ноты во времени:
//
//      1 |   /\
//        |  /  \______ S          A: attack  — рост 0 -> 1
//        | /          |\          D: decay   — спад 1 -> S
//      0 |/           | \___      S: sustain — уровень, пока нота нажата
//         A   D   S   R           R: release — спад от ТЕКУЩЕГО уровня к 0
//                     ^ note_off
//
//  Тонкость: note_off может прийти посреди атаки — release должен идти
//  от текущего уровня, а не от S, иначе громкость скачком прыгнет (щелчок).
//
//  ЗАДАЧА: реализуйте resample_linear, LowPass.process и Adsr.next.
//
import std::io, std::math;

// Ресэмплинг int16 с шагом step (16.16). Пишет out.len сэмплов.
// Сэмплы за концом входа считаются равными последнему сэмплу.
// Возвращает финальную позицию (16.16).
fn uint resample_linear(short[] input, uint step, short[] out)
{
    uint pos = 0;
    foreach (&o : out)
    {
        usz i = (usz)(pos >> 16);
        int frac = (int)(pos & 0xFFFF);
        int a = i < input.len ? input[i] : input[^1];
        int b = i + 1 < input.len ? input[i + 1] : input[^1];
        *o = (short)(a + (((b - a) * frac) >> 16));
        pos += step;
    }
    return pos;
}

struct LowPass
{
    float a;
    float y;    // состояние между блоками
}

fn void LowPass.process(&self, float[] buf)
{
    float y = self.y;
    foreach (&x : buf)
    {
        y += self.a * (*x - y);
        *x = y;
    }
    self.y = y;
}

enum AdsrStage
{
    IDLE,
    ATTACK,
    DECAY,
    SUSTAIN,
    RELEASE,
}

struct Adsr
{
    int attack;     // длительности в сэмплах (> 0)
    int decay;
    float sustain;  // уровень 0..1
    int release;
    AdsrStage stage;
    float level;
    float release_step;   // на сколько уменьшать уровень за сэмпл в RELEASE
}

fn void Adsr.note_on(&self)
{
    self.stage = ATTACK;
}

fn void Adsr.note_off(&self)
{
    if (self.stage == IDLE) return;
    self.stage = RELEASE;
    self.release_step = self.level / (float)self.release;
}

// Сдвинуться на один сэмпл и вернуть новый уровень.
fn float Adsr.next(&self)
{
    switch (self.stage)
    {
        case IDLE:
            self.level = 0;
        case ATTACK:
            self.level += 1.0f / (float)self.attack;
            if (self.level >= 1.0f) { self.level = 1.0f; self.stage = DECAY; }
        case DECAY:
            self.level -= (1.0f - self.sustain) / (float)self.decay;
            if (self.level <= self.sustain) { self.level = self.sustain; self.stage = SUSTAIN; }
        case SUSTAIN:
            self.level = self.sustain;
        case RELEASE:
            self.level -= self.release_step;
            if (self.level <= 0.0f) { self.level = 0.0f; self.stage = IDLE; }
    }
    return self.level;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

fn int pct(float x) => (int)math::round(x * 1000.0f);

fn void main()
{
    // --- ресэмплинг
    short[5] src = { 0, 1000, 2000, -1000, 500 };
    short[8] same;
    resample_linear(&src, 1 << 16, &same);       // шаг 1.0 — копия
    for (int i = 0; i < 5; i++) assert(same[i] == src[i], "шаг 1.0 должен давать копию");
    assert(same[7] == 500, "за концом — последний сэмпл");

    short[9] up;
    uint end = resample_linear(&src, 1 << 15, &up);   // шаг 0.5 — вдвое больше сэмплов
    assert(up[1] == 500 && up[5] == 500 && up[7] == -250, "середины между соседями");
    assert(end == 9 << 15);
    io::printfn("up x2:   %s", up);

    short[4] down;
    resample_linear(&src, 0x14000, &down);       // шаг 1.25 (выше тон)
    io::printfn("pitch up: %s", down);

    short[6] odd;
    resample_linear(&src, 22050 * 65536 / 48000, &odd);   // 22050 -> 48000 Гц
    io::printfn("22k->48k: %s", odd);

    // --- фильтр: ступенька 0 -> 1, обработанная ДВУМЯ блоками
    LowPass lp = { .a = 0.5f };
    float[4] blk1 = { 1, 1, 1, 1 };
    float[4] blk2 = { 1, 1, 1, 1 };
    lp.process(&blk1);
    lp.process(&blk2);
    assert(blk1[0] == 0.5f && blk1[1] == 0.75f, "y += a*(x-y)");
    assert(blk2[0] == blk1[3] + 0.5f * (1 - blk1[3]), "состояние должно переживать границу блока");
    io::printfn("lowpass: %d %d %d", pct(blk1[3]), pct(blk2[0]), pct(blk2[3]));

    // --- ADSR
    Adsr env = { .attack = 4, .decay = 4, .sustain = 0.5f, .release = 5 };
    env.note_on();
    float[10] trace;
    foreach (&t : trace) *t = env.next();
    assert(trace[3] == 1.0f && env.stage == SUSTAIN && trace[9] == 0.5f);
    io::printf("adsr on: ");
    foreach (t : trace) io::printf("%d ", pct(t));
    io::printn();
    env.note_off();
    io::printf("adsr off:");
    for (int i = 0; i < 6; i++) io::printf(" %d", pct(env.next()));
    io::printn();
    assert(env.stage == IDLE && env.level == 0);

    // note_off посреди атаки: release от текущего уровня, без скачка
    Adsr e2 = { .attack = 10, .decay = 2, .sustain = 0.8f, .release = 3 };
    e2.note_on();
    e2.next(); e2.next(); e2.next();
    float before = e2.level;
    e2.note_off();
    float after = e2.next();
    assert(after < before && before - after < 0.11f, "release от текущего уровня");
    io::printfn("early release: %d -> %d", pct(before), pct(after));
}
