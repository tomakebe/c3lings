// =====================================================================
//  e1002 · Абстракция устройств и мёртвые зоны
// =====================================================================
//
//  Сначала прочитайте engine/docs/10_input.md (разделы «Слой платформы
//  и сырые события» и «Аналоговые оси и мёртвые зоны»).
//
//  Платформенный слой отдаёт сырые события в духе Linux evdev — тройки
//  (kind, code, value):
//
//      KEY          code = USB HID scancode, value = 1/0
//      MOUSE_BUTTON code = номер кнопки,     value = 1/0
//      MOUSE_MOVE   code = 0 (x) / 1 (y),    value = смещение в пикселях
//      PAD_BUTTON   code = индекс кнопки,    value = 1/0
//      PAD_AXIS     code = 0 LX, 1 LY, 5 RT, value = short (-32768..32767)
//
//  Игре эти коды не нужны. Задача слоя ввода — превратить их в
//  НЕЗАВИСИМОЕ от устройства состояние:
//
//      * кнопки — по единому перечислению Control (KEY_W, PAD_SOUTH, ...),
//      * оси — в фиксированной точке: целые -1000..1000 («промилле»),
//      * дельты мыши — сумма за кадр,
//      * last_device — каким устройством игрок пользовался последним
//        (по нему UI переключает подсказки «Press [A]» / «Press [Space]»).
//
//  Мёртвые зоны. Стик в покое отдаёт не 0, а шум (±2000 — нормально для
//  изношенного геймпада). Поэтому:
//
//    * Осевая (axial) зона с перемасштабированием — для триггера и
//      одиночных осей:   |v| <= dz  -> 0
//                        иначе      -> sign(v) * (|v| - dz) * 1000 / (32767 - dz)
//      (с ограничением до 1000; осторожно: -32768 по модулю больше 32767!)
//      Перемасштабирование важно: без него на выходе из зоны значение
//      скачком прыгает с 0 до dz, и тонко прицелиться невозможно.
//
//    * Радиальная (radial) зона — для стика целиком. Если применять
//      осевую зону к x и y по отдельности, то движение по диагонали
//      «прилипает» к осям (крестообразная зона). Радиальная берёт длину
//      вектора m = sqrt(x*x + y*y):
//                        m <= dz  -> (0, 0)
//                        иначе    -> nm = min(1000, (m - dz) * 1000 / (32767 - dz))
//                                    x' = x * nm / m,  y' = y * nm / m
//      Направление сохраняется, а длина плавно растёт от 0.
//
//  Ловушка «дрейфа»: если любое событие PAD_AXIS переключает
//  last_device на GAMEPAD, то лежащий на столе геймпад с шумящим стиком
//  постоянно отбирает UI у клавиатуры. Переключайте устройство только
//  если ПОСЛЕ мёртвой зоны ось не нулевая.
//
//  ЗАДАЧА: реализуйте axial_deadzone, radial_deadzone, InputState.apply
//  и InputState.move_x (все помечены TODO).
//
import std::io;
import std::math;

const int AXIS_MAX = 1000;     // 1.0 в фиксированной точке
const int RAW_MAX = 32767;

enum RawKind : char { KEY, MOUSE_BUTTON, MOUSE_MOVE, PAD_BUTTON, PAD_AXIS }

struct RawEvent
{
    RawKind kind;
    uint code;
    int value;
}

enum Device : char { NONE, KEYBOARD, MOUSE, GAMEPAD }

enum Control : char
{
    KEY_A, KEY_D, KEY_W, KEY_S, KEY_SPACE,
    MOUSE_LEFT,
    PAD_SOUTH, PAD_EAST, PAD_START,
}

excuse UNMAPPED;

// Таблицы трансляции платформенных кодов (на настоящем движке их
// генерируют из данных и держат по одной на платформу).
fn Control? key_from_scancode(uint sc)
{
    switch (sc)
    {
        case 4:  return KEY_A;
        case 7:  return KEY_D;
        case 26: return KEY_W;
        case 22: return KEY_S;
        case 44: return KEY_SPACE;
        default: return UNMAPPED~;
    }
}

fn Control? pad_button_from_index(uint idx)
{
    switch (idx)
    {
        case 0: return PAD_SOUTH;
        case 1: return PAD_EAST;
        case 7: return PAD_START;
        default: return UNMAPPED~;
    }
}

// Целочисленный корень (floor(sqrt(n))) — чтобы не тащить float в слой
// ввода и получать бит-в-бит одинаковый результат на любой платформе.
fn long isqrt(long n)
{
    if (n < 2) return n;
    long x = n;
    long y = (x + 1) / 2;
    while (y < x)
    {
        x = y;
        y = (x + n / x) / 2;
    }
    return x;
}

// Осевая мёртвая зона с перемасштабированием. Результат в -1000..1000.
fn int axial_deadzone(int raw, int dz)
{
    int a = raw < 0 ? -raw : raw;
    if (a <= dz) return 0;
    int v = (a - dz) * AXIS_MAX / (RAW_MAX - dz);
    if (v > AXIS_MAX) v = AXIS_MAX;
    return raw < 0 ? -v : v;
}

// Радиальная мёртвая зона для стика. Пишет результат в *out_x, *out_y.
fn void radial_deadzone(int raw_x, int raw_y, int dz, int* out_x, int* out_y)
{
    long x = raw_x;
    long y = raw_y;
    long m = isqrt(x * x + y * y);
    if (m <= dz)
    {
        *out_x = 0;
        *out_y = 0;
        return;
    }
    long nm = math::min((m - dz) * AXIS_MAX / (long)(RAW_MAX - dz), (long)AXIS_MAX);
    *out_x = (int)(x * nm / m);
    *out_y = (int)(y * nm / m);
}

const int STICK_DZ = 8000;
const int TRIGGER_DZ = 3000;

struct InputState
{
    bool[Control::len] buttons;
    int raw_lx, raw_ly;           // сырые значения стика (нужны оба сразу)
    int stick_x, stick_y;         // после радиальной зоны, -1000..1000
    int trigger;                  // после осевой зоны, 0..1000
    int mouse_dx, mouse_dy;       // сумма за кадр
    Device last_device;
    int unmapped;                 // сколько событий не удалось распознать
}

fn void InputState.begin_frame(&self)
{
    self.mouse_dx = 0;
    self.mouse_dy = 0;
}

fn void InputState.apply(&self, RawEvent e)
{
    switch (e.kind)
    {
        case KEY:
            if (try c = key_from_scancode(e.code))
            {
                self.buttons[c] = e.value != 0;
                self.last_device = KEYBOARD;
            }
            else
            {
                self.unmapped++;
            }
        case MOUSE_BUTTON:
            if (e.code != 0)
            {
                self.unmapped++;
                break;
            }
            self.buttons[Control.MOUSE_LEFT] = e.value != 0;
            self.last_device = MOUSE;
        case MOUSE_MOVE:
            switch (e.code)
            {
                case 0: self.mouse_dx += e.value;
                case 1: self.mouse_dy += e.value;
                default: self.unmapped++; break;
            }
            if (e.value != 0) self.last_device = MOUSE;
        case PAD_BUTTON:
            if (try c = pad_button_from_index(e.code))
            {
                self.buttons[c] = e.value != 0;
                self.last_device = GAMEPAD;
            }
            else
            {
                self.unmapped++;
            }
        case PAD_AXIS:
            bool active;
            switch (e.code)
            {
                case 0:
                case 1:
                    if (e.code == 0)
                    {
                        self.raw_lx = e.value;
                    }
                    else
                    {
                        self.raw_ly = e.value;
                    }
                    radial_deadzone(self.raw_lx, self.raw_ly, STICK_DZ, &self.stick_x, &self.stick_y);
                    active = self.stick_x != 0 || self.stick_y != 0;
                case 5:
                    self.trigger = axial_deadzone(e.value, TRIGGER_DZ);
                    active = self.trigger != 0;
                default:
                    self.unmapped++;
            }
            if (active) self.last_device = GAMEPAD;
    }
}

// Горизонтальное движение, не зависящее от устройства: клавиатура даёт
// (D - A) * 1000, стик — stick_x. Побеждает то, что по модулю больше
// (при равенстве — клавиатура).
fn int InputState.move_x(&self)
{
    int keys = 0;
    if (self.buttons[Control.KEY_D]) keys += AXIS_MAX;
    if (self.buttons[Control.KEY_A]) keys -= AXIS_MAX;
    int ak = keys < 0 ? -keys : keys;
    int as = self.stick_x < 0 ? -self.stick_x : self.stick_x;
    return ak >= as ? keys : self.stick_x;
}

// ---------------------------------------------------------------------

fn void print_state(int frame, InputState* s)
{
    io::printfn("frame %d: move_x=%d stick=(%d,%d) trigger=%d mouse=(%d,%d) south=%s left=%s device=%s unmapped=%d",
        frame, s.move_x(), s.stick_x, s.stick_y, s.trigger, s.mouse_dx, s.mouse_dy,
        s.buttons[Control.PAD_SOUTH], s.buttons[Control.MOUSE_LEFT], s.last_device, s.unmapped);
}

fn void main()
{
    // Сначала — сами функции мёртвых зон.
    assert(axial_deadzone(0, 8000) == 0);
    assert(axial_deadzone(7999, 8000) == 0);
    assert(axial_deadzone(-8000, 8000) == 0);
    assert(axial_deadzone(32767, 8000) == 1000);
    assert(axial_deadzone(-32768, 8000) == -1000, "-32768 must clamp to -1000");
    assert(axial_deadzone(20383, 8000) == 499);
    assert(axial_deadzone(-20383, 8000) == -499);

    int x, y;
    radial_deadzone(5000, 5000, 8000, &x, &y);     // |v| ~ 7071 < 8000
    assert(x == 0 && y == 0, "diagonal inside the radial zone must be zero");
    radial_deadzone(30000, 0, 8000, &x, &y);
    assert(x == 888 && y == 0);
    radial_deadzone(-23170, 23170, 8000, &x, &y);  // длина ~ 32767 по диагонали
    assert(x == -707 && y == 707);
    radial_deadzone(32767, 32767, 8000, &x, &y);   // за пределами круга -> длина 1000
    assert(x == 707 && y == 707);
    io::printn("deadzones ok");

    RawEvent[][] frames = {
        // 0: шум стика на столе — устройство не должно переключиться
        { { PAD_AXIS, 0, 1500 }, { PAD_AXIS, 1, -1200 } },
        // 1: клавиатура: D нажата, неизвестная клавиша F12 (69)
        { { KEY, 7, 1 }, { KEY, 69, 1 } },
        // 2: мышь: два смещения за кадр + левая кнопка
        { { MOUSE_MOVE, 0, 3 }, { MOUSE_MOVE, 0, 4 }, { MOUSE_MOVE, 1, -2 }, { MOUSE_BUTTON, 0, 1 } },
        // 3: мышь и D отпущены, стик влево (вне зоны) — геймпад перехватывает
        { { MOUSE_BUTTON, 0, 0 }, { KEY, 7, 0 }, { PAD_AXIS, 0, -30000 }, { PAD_AXIS, 1, 0 } },
        // 4: A нажата; стик чуть-чуть влево — клавиатура сильнее
        { { KEY, 4, 1 }, { PAD_AXIS, 0, -12000 } },
        // 5: кнопки геймпада и триггер
        { { KEY, 4, 0 }, { PAD_BUTTON, 0, 1 }, { PAD_BUTTON, 3, 1 }, { PAD_AXIS, 5, 17884 } },
        // 6: всё отпущено
        { { PAD_AXIS, 0, 0 }, { PAD_AXIS, 5, 0 }, { PAD_BUTTON, 0, 0 } },
    };

    InputState s;
    foreach (i, evs : frames)
    {
        s.begin_frame();
        foreach (e : evs) s.apply(e);
        print_state((int)i, &s);
        switch (i)
        {
            case 0: assert(s.last_device == NONE, "stick drift must not steal the device");
            case 1: assert(s.move_x() == 1000 && s.last_device == KEYBOARD && s.unmapped == 1);
            case 2: assert(s.mouse_dx == 7 && s.mouse_dy == -2 && s.buttons[Control.MOUSE_LEFT]);
            case 3: assert(s.move_x() == -888 && s.last_device == GAMEPAD);
            case 4: assert(s.move_x() == -1000 && s.mouse_dx == 0);
            case 5: assert(s.trigger == 500 && s.buttons[Control.PAD_SOUTH] && s.unmapped == 2);
            case 6: assert(s.move_x() == 0 && s.trigger == 0 && !s.buttons[Control.PAD_SOUTH]);
        }
    }
    io::printn("device abstraction ok");
}
