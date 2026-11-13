// =====================================================================
//  e1004 · Буфер ввода и распознавание комбо (файтинги)
// =====================================================================
//
//  Сначала прочитайте engine/docs/10_input.md (раздел «Буферизация ввода
//  и комбо»).
//
//  Направления в файтингах записывают в «нумпад-нотации» (смотрим на
//  цифровую клавиатуру, персонаж смотрит вправо):
//
//        7 8 9          5 — нейтраль
//        4 5 6          6 — вперёд, 4 — назад
//        1 2 3          2 — вниз, 3 — вниз-вперёд ...
//
//  «Хадокен» — 236P: вниз, вниз-вперёд, вперёд + удар.
//  «Шорюкен» — 623P: вперёд, вниз, вниз-вперёд + удар.
//
//  Буфер ввода — кольцевой буфер записей { frame, dir, punch }.
//  Запись добавляется, только когда направление ИЗМЕНИЛОСЬ или нажат
//  удар — удержание стика буфер не засоряет.
//
//  Распознавание идёт ОТ НОВЫХ К СТАРЫМ:
//    1) находим самое свежее нажатие удара, которое
//         * не старше BUTTON_BUFFER кадров (now - frame <= BUTTON_BUFFER),
//         * ещё не «потрачено» (frame > consumed_frame);
//       более старые записи с ударом не рассматриваем.
//    2) от этой записи (включительно — направление могло смениться в
//       тот же кадр, что и удар) идём к более старым и ищем направления
//       движения В ОБРАТНОМ ПОРЯДКЕ (для 236 — сначала 6, потом 3,
//       потом 2). Посторонние направления между ними пропускаются —
//       это и есть leniency, без неё живой человек не попадёт.
//    3) но между соседними найденными шагами не больше STEP_GAP кадров
//       (если очередная просмотренная запись старше последнего найденного
//       шага больше чем на STEP_GAP — провал), а всё движение от первого
//       шага до удара — не длиннее motion.window кадров.
//    4) записи с frame <= consumed_frame тоже потрачены: дойдя до такой
//       записи, поиск проваливается. Иначе при серии хадокенов «6» от
//       первого и «23» от второго сложатся в 623 — и вместо второго
//       хадокена вылетит шорюкен (реальный баг многих любительских
//       файтингов; посмотрите тест «two fireballs»).
//
//  Если персонаж смотрит влево, направления зеркалятся: 4<->6, 1<->3,
//  7<->9 (2, 5, 8 — без изменений). Зеркалим ВХОД, а не таблицу движений.
//
//  Буферизация нажатия (BUTTON_BUFFER) нужна, чтобы удар, нажатый за
//  пару кадров до конца восстановления после предыдущего приёма, всё
//  равно сработал. После срабатывания нажатие помечается потраченным,
//  иначе приём сработает повторно в следующем кадре.
//
//  Порядок проверки приёмов — приоритет: 6236P подходит и под 623, и под
//  236; принято отдавать его «шорюкену» (DRAGON проверяется первым).
//
//  ЗАДАЧА: реализуйте mirror и match_motion (TODO). Остальное готово.
//
import std::io;

const uint BUTTON_BUFFER = 4;
const uint STEP_GAP = 8;
const int RING = 32;

struct InputEntry
{
    uint frame;
    char dir;      // '1'..'9'
    bool punch;
}

struct InputBuffer
{
    InputEntry[RING] ring;
    uint count;            // сколько всего записано (берём последние RING)
    char last_dir;
    long consumed_frame;   // нажатия с frame <= consumed_frame потрачены
}

fn void InputBuffer.init(&self)
{
    *self = {};
    self.last_dir = '5';
    self.consumed_frame = -1;
}

fn void InputBuffer.feed(&self, uint frame, char dir, bool punch_pressed)
{
    if (dir == self.last_dir && !punch_pressed) return;
    self.last_dir = dir;
    self.ring[self.count % RING] = { frame, dir, punch_pressed };
    self.count++;
}

fn uint InputBuffer.len(&self) => self.count < RING ? self.count : RING;

// i = 0 — самая свежая запись, i = 1 — предыдущая и т.д.
fn InputEntry InputBuffer.back(&self, uint i)
{
    assert(i < self.len());
    return self.ring[(self.count - 1 - i) % RING];
}

struct Motion
{
    String name;
    String dirs;   // например "236"
    uint window;
}

// Зеркальное направление для персонажа, смотрящего влево.
fn char mirror(char dir)
{
    // TODO
    return dir;
}

<*
 Распознать motion+P в буфере. При успехе вернуть кадр нажатия удара
 (его потратит вызывающий), иначе -1.
*>
fn long match_motion(InputBuffer* buf, Motion m, uint now, bool facing_right)
{
    // TODO: шаг 1 — найти свежее непотраченное нажатие;
    //       шаг 2-3 — найти m.dirs в обратном порядке с учётом
    //       STEP_GAP, m.window, consumed_frame и зеркалирования.
    return -1;
}

enum Move : char { NONE, PUNCH, FIREBALL, DRAGON }

Motion[] motions = {
    { "DRAGON", "623", 20 },
    { "FIREBALL", "236", 15 },
};

fn Move detect(InputBuffer* buf, uint now, bool facing_right)
{
    foreach (i, m : motions)
    {
        long f = match_motion(buf, m, now, facing_right);
        if (f >= 0)
        {
            buf.consumed_frame = f;
            return i == 0 ? DRAGON : FIREBALL;
        }
    }
    // Простой удар: свежее непотраченное нажатие без движения.
    for (uint i = 0; i < buf.len(); i++)
    {
        InputEntry e = buf.back(i);
        if (now - e.frame > BUTTON_BUFFER || e.frame <= buf.consumed_frame) break;
        if (e.punch)
        {
            buf.consumed_frame = e.frame;
            return PUNCH;
        }
    }
    return NONE;
}

// ---------------------------------------------------------------------
// Сценарии: отрезки «столько-то кадров держим направление», удар — в
// первом кадре отрезка. busy_until — до этого кадра персонаж в
// восстановлении и detect не вызывается.

struct Segment { uint frames; char dir; bool punch; }

fn String run(String title, Segment[] script, bool facing_right = true, uint busy_until = 0)
{
    InputBuffer buf;
    buf.init();
    io::printf("%-22s:", title);
    uint frame = 0;
    String result = "NONE";
    foreach (s : script)
    {
        for (uint k = 0; k < s.frames; k++, frame++)
        {
            buf.feed(frame, s.dir, s.punch && k == 0);
            if (frame < busy_until) continue;
            Move mv = detect(&buf, frame, facing_right);
            if (mv != NONE)
            {
                io::printf(" %s@%d", mv, frame);
                result = mv == FIREBALL ? "FIREBALL" : mv == DRAGON ? "DRAGON" : "PUNCH";
            }
        }
    }
    io::printn();
    return result;
}

fn void main()
{
    assert(mirror('6') == '4' && mirror('4') == '6');
    assert(mirror('3') == '1' && mirror('7') == '9' && mirror('9') == '7');
    assert(mirror('2') == '2' && mirror('5') == '5' && mirror('8') == '8');

    String r;
    r = run("clean 236P", { { 3, '5', false }, { 2, '2', false }, { 2, '3', false }, { 3, '6', true } });
    assert(r == "FIREBALL");

    r = run("mirrored 214P", { { 2, '2', false }, { 2, '1', false }, { 3, '4', true } }, facing_right: false);
    assert(r == "FIREBALL");

    r = run("214P facing right", { { 2, '2', false }, { 2, '1', false }, { 3, '4', true } });
    assert(r == "PUNCH");

    r = run("sloppy 2(5)36P", { { 2, '2', false }, { 1, '5', false }, { 1, '3', false }, { 2, '6', true } });
    assert(r == "FIREBALL");

    r = run("6236P priority", { { 2, '6', false }, { 2, '2', false }, { 2, '3', false }, { 3, '6', true } });
    assert(r == "DRAGON");

    r = run("too slow 2..36P", { { 12, '2', false }, { 2, '3', false }, { 2, '6', true } });
    assert(r == "PUNCH");

    r = run("window 20 > 15", { { 2, '2', false }, { 7, '1', false }, { 7, '3', false }, { 4, '6', false }, { 1, '6', true } });
    assert(r == "PUNCH");

    r = run("buffered in recovery", { { 15, '5', false }, { 1, '2', false }, { 1, '3', false }, { 6, '6', true } }, busy_until: 20);
    assert(r == "FIREBALL");

    r = run("pressed too early", { { 15, '5', false }, { 1, '2', false }, { 1, '3', false }, { 15, '6', true } }, busy_until: 30);
    assert(r == "NONE");

    r = run("two fireballs", { { 1, '2', false }, { 1, '3', false }, { 1, '6', true }, { 3, '5', false },
                               { 1, '2', false }, { 1, '3', false }, { 1, '6', true }, { 2, '5', false } });
    assert(r == "FIREBALL");

    io::printn("combo buffer ok");
}
