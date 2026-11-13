// ---------------------------------------------------------------------
//  mini::input — состояние кнопок, фронты нажатий и запись/воспроизведение
//  ввода (глава 10).
//
//  Ввод за тик — битовая маска кнопок. Из двух масок (прошлый и текущий
//  тик) получаются фронты: pressed = held & ~prev, released = prev & ~held.
//
//  Запись ввода хранит только ИЗМЕНЕНИЯ: {tick, bits}. Детерминированная
//  симуляция + записанный ввод = реплей, автотест, воспроизведение бага,
//  а в сети — lockstep (глава 18).
// ---------------------------------------------------------------------
module mini::input;

enum Button : char
{
    LEFT,
    RIGHT,
    THRUST,
    FIRE,
}

fn char bit(Button b) => (char)(1 << b.ordinal);

struct InputState
{
    char held;
    char prev;
}

fn void InputState.update(&self, char bits)
{
    self.prev = self.held;
    self.held = bits;
}

fn bool InputState.down(&self, Button b) => (self.held & bit(b)) != 0;

fn bool InputState.pressed(&self, Button b)
{
    return (self.held & bit(b)) != 0; // TODO: фронт, а не удержание
}

fn bool InputState.released(&self, Button b)
{
    (void)b;
    return false; // TODO
}

struct InputEvent
{
    int tick;
    char bits;
}

const int MAX_EVENTS = 256;

struct Recording
{
    InputEvent[MAX_EVENTS] events;
    int count;
    char last;
    int cursor;     // для воспроизведения
    char current;
}

<* Записать маску тика; событие добавляется, только если маска изменилась. *>
fn void Recording.record(&self, int tick, char bits)
{
    // TODO: хранить только изменения (нулевой ввод в начале не записывать)
    (void)tick;
    (void)bits;
}

fn void Recording.rewind(&self)
{
    self.cursor = 0;
    self.current = 0;
}

<* Маска на тике tick. Тики запрашиваются по возрастанию. *>
fn char Recording.play(&self, int tick)
{
    // TODO: продвинуть cursor по событиям с tick <= запрошенного
    (void)tick;
    return 0;
}
