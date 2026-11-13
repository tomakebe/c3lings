// =====================================================================
//  e1001 · Ввод: pressed / held / released без потерь
// =====================================================================
//
//  Сначала прочитайте engine/docs/10_input.md (разделы «Опрос или
//  события» и «Фронты: pressed/held/released»).
//
//  Игре почти никогда не нужно «нажата ли клавиша прямо сейчас» само по
//  себе. Ей нужны три вопроса на кадр:
//
//      held(k)      — клавиша удерживается (уровень сигнала)
//      pressed(k)   — клавиша была НАЖАТА в этом кадре (передний фронт)
//      released(k)  — клавиша была ОТПУЩЕНА в этом кадре (задний фронт)
//
//  Наивный способ — хранить состояние прошлого кадра и сравнивать:
//
//      pressed  = down & ~prev_down
//      released = ~down & prev_down
//
//  Он ломается, если ОС прислала и нажатие, и отпускание между двумя
//  кадрами (быстрый тап на 30 FPS, лаг кадра, загрузка). Снимок состояния
//  не видит ничего: до кадра клавиша была отпущена, после — тоже.
//  Прыжок «съеден». Ровно та же беда с «отпустил и сразу нажал»:
//  наивный способ видит held без всяких фронтов.
//
//  Правильно — «защёлкивать» фронты в обработчике событий: каждое
//  событие нажатия ставит бит в маске pressed_bits, каждое отпускание — в
//  маске released_bits, а в начале кадра маски очищаются. Состояние down
//  при этом тоже ведётся по событиям.
//
//  Ещё одна деталь: автоповтор ОС присылает «down» для уже нажатой
//  клавиши. Это НЕ новое нажатие — его нужно игнорировать.
//
//  Заметьте: поля названы pressed_bits/released_bits, потому что в C3
//  метод не может называться так же, как поле структуры.
//
//  Все клавиши — биты одного ulong (до 64 клавиш), бит = 1ul << ordinal.
//  Битовые маски дешевы: весь «снимок клавиатуры» — 4 машинных слова,
//  его тривиально копировать, сравнивать и записывать в реплей.
//
//  ЗАДАЧА: реализуйте begin_frame, on_event, held, pressed, released
//  (помечены TODO). Метод naive_pressed уже написан — он нужен, чтобы
//  увидеть разницу в выводе.
//
import std::io;

enum Key : char
{
    A, D, W, S, SPACE, ESC
}

struct Keyboard
{
    ulong down;       // текущее состояние, ведётся по событиям
    ulong prev_down;  // down на начало кадра (для наивного способа)
    ulong pressed_bits;  // защёлкнутые за кадр передние фронты
    ulong released_bits;  // защёлкнутые за кадр задние фронты
}

macro ulong bit(Key k) => 1ul << k.ordinal;

// Вызывается в начале кадра, ДО обработки событий этого кадра.
fn void Keyboard.begin_frame(&self)
{
    // TODO: запомните down в prev_down и очистите маски фронтов (pressed_bits, released_bits)
}

// Вызывается для каждого события от ОС.
fn void Keyboard.on_event(&self, Key k, bool is_down)
{
    // TODO: обновите down; поставьте бит в pressed/released.
    //       Автоповтор (down для уже нажатой клавиши) игнорируйте,
    //       как и up для уже отпущенной.
}

fn bool Keyboard.held(&self, Key k)     => false; // TODO
fn bool Keyboard.pressed(&self, Key k)  => false; // TODO
fn bool Keyboard.released(&self, Key k) => false; // TODO

fn bool Keyboard.naive_pressed(&self, Key k) => (self.down & ~self.prev_down & bit(k)) != 0;

// ---------------------------------------------------------------------
// Тестовый стенд: события, пришедшие между кадрами.

struct Event { Key key; bool down; }

fn void print_set(Keyboard* kb, String label, String which)
{
    io::printf(" %s=[", label);
    bool first = true;
    foreach (k : Key::values)
    {
        bool on;
        switch (which)
        {
            case "held": on = kb.held(k);
            case "pressed": on = kb.pressed(k);
            case "released": on = kb.released(k);
            default: on = kb.naive_pressed(k);
        }
        if (!on) continue;
        if (!first) io::print(",");
        io::printf("%s", k);
        first = false;
    }
    io::print("]");
}

fn void main()
{
    Event[][] frames = {
        { { A, true } },                                // 0: нажали A
        { },                                            // 1: держим A
        { { A, false } },                               // 2: отпустили A
        { { SPACE, true }, { SPACE, false } },          // 3: тап за один кадр
        { { W, true }, { W, true }, { D, true } },      // 4: W + автоповтор, D
        { { W, false }, { W, true }, { D, false } },    // 5: W перенажат, D отпущен
        { { ESC, false } },                             // 6: лишнее up
    };

    Keyboard kb;
    int jumps;
    foreach (i, evs : frames)
    {
        kb.begin_frame();
        foreach (e : evs) kb.on_event(e.key, e.down);
        if (kb.pressed(SPACE)) jumps++;

        io::printf("frame %d:", i);
        print_set(&kb, "held", "held");
        print_set(&kb, "pressed", "pressed");
        print_set(&kb, "released", "released");
        print_set(&kb, "naive", "naive");
        io::printn();
    }

    // Самопроверка.
    assert(jumps == 1, "tap within one frame must produce a jump");
    assert(kb.held(W) && !kb.held(D) && !kb.held(SPACE));
    assert(kb.down == bit(W));
    io::printfn("jumps: %d", jumps);
    io::printn("edge detection ok");
}
