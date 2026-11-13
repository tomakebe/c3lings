// =====================================================================
//  e1003 · Action mapping и стек контекстов ввода
// =====================================================================
//
//  Сначала прочитайте engine/docs/10_input.md (разделы «Действия вместо
//  клавиш» и «Контексты ввода»).
//
//  Геймплейный код не должен спрашивать «нажат ли пробел». Он
//  спрашивает «было ли действие JUMP». Между ними — таблица привязок
//  (bindings) control -> action. Это даёт:
//    * переназначение клавиш без перекомпиляции (настройки игрока),
//    * несколько устройств на одно действие (SPACE и PAD_SOUTH -> JUMP),
//    * один и тот же control в разных ситуациях означает разное.
//
//  Последнее решается КОНТЕКСТАМИ (Unreal Enhanced Input называет их
//  Input Mapping Context с приоритетом, Unity Input System — Action
//  Maps). Контексты лежат стеком:
//
//      top    menu      (blocking)      W->MENU_UP, ENTER->CONFIRM, ...
//             dialog    (non-blocking)  SPACE->DIALOG_NEXT, ...
//      bottom gameplay  (non-blocking)  W->MOVE_FORWARD, SPACE->JUMP, ...
//
//  Алгоритм разрешения за кадр:
//      remaining = нажатые controls
//      идём от вершины стека вниз:
//          для каждой привязки контекста: если её control есть в
//              remaining — действие срабатывает, control помечается
//              как ПОГЛОЩЁННЫЙ (consumed);
//          после обхода контекста убираем поглощённые из remaining
//              (внутри одного контекста один control может
//              запустить несколько действий);
//          если контекст blocking — ниже не идём вообще.
//
//  Так диалог «съедает» пробел (персонаж не прыгает, пока листаем
//  реплики), но W проходит насквозь и персонаж ходит. А меню паузы
//  blocking — ничего из геймплея не срабатывает.
//
//  Переназначение (rebind) должно ловить конфликты: если новый control
//  уже привязан в ЭТОМ ЖЕ контексте к другому действию — ошибка
//  CONFLICT. Если у действия нет привязки к old — NOT_BOUND.
//
//  ЗАДАЧА: реализуйте ActionMap.resolve и Context.rebind (TODO).
//
import std::io;
import std::collections::list;

enum Control : char
{
    KEY_W, KEY_S, KEY_E, KEY_J, KEY_SPACE, KEY_ENTER, KEY_ESC,
    PAD_SOUTH, PAD_EAST, PAD_START, PAD_DUP, PAD_DDOWN,
}

enum Action : char
{
    MOVE_FORWARD, JUMP, INTERACT, PAUSE,
    DIALOG_NEXT,
    MENU_UP, MENU_DOWN, CONFIRM, BACK,
}

macro ulong cbit(Control c) => 1ul << c.ordinal;
macro ulong abit(Action a) => 1ul << a.ordinal;

struct Binding
{
    Control control;
    Action action;
}

struct Context
{
    String name;
    bool blocking;
    List{Binding} bindings;
}

fn void Context.bind(&self, Control c, Action a) => self.bindings.push({ c, a });

excuse NOT_BOUND, CONFLICT;

<*
 Заменить привязку `old` действия `a` на `new_control`.
*>
fn void? Context.rebind(&self, Action a, Control old, Control new_control)
{
    // TODO: 1) если new_control уже привязан к ДРУГОМУ действию в этом
    //          контексте — return CONFLICT~;
    //       2) найдите привязку (old, a) и замените control;
    //       3) не нашли — return NOT_BOUND~.
    return NOT_BOUND~;
}

const int MAX_DEPTH = 8;

struct ActionMap
{
    Context*[MAX_DEPTH] stack;
    int depth;
}

fn void ActionMap.push(&self, Context* c)
{
    assert(self.depth < MAX_DEPTH);
    self.stack[self.depth++] = c;
}

fn void ActionMap.pop(&self)
{
    assert(self.depth > 0);
    self.depth--;
}

<*
 По маске нажатых controls вернуть маску сработавших действий.
*>
fn ulong ActionMap.resolve(&self, ulong pressed)
{
    // TODO: обойдите стек от вершины (stack[depth - 1]) вниз.
    return 0;
}

// ---------------------------------------------------------------------

fn void print_actions(String label, ulong actions)
{
    io::printf("%-28s ->", label);
    if (!actions) io::print(" (none)");
    foreach (a : Action::values)
    {
        if (actions & abit(a)) io::printf(" %s", a);
    }
    io::printn();
}

fn void main()
{
    Context gameplay = { .name = "gameplay" };
    gameplay.bind(KEY_W, MOVE_FORWARD);
    gameplay.bind(KEY_SPACE, JUMP);
    gameplay.bind(PAD_SOUTH, JUMP);
    gameplay.bind(KEY_E, INTERACT);
    gameplay.bind(PAD_EAST, INTERACT);
    gameplay.bind(KEY_ESC, PAUSE);
    gameplay.bind(PAD_START, PAUSE);

    Context dialog = { .name = "dialog" };
    dialog.bind(KEY_SPACE, DIALOG_NEXT);
    dialog.bind(PAD_SOUTH, DIALOG_NEXT);
    dialog.bind(KEY_E, DIALOG_NEXT);

    Context menu = { .name = "menu", .blocking = true };
    menu.bind(KEY_W, MENU_UP);
    menu.bind(PAD_DUP, MENU_UP);
    menu.bind(KEY_S, MENU_DOWN);
    menu.bind(PAD_DDOWN, MENU_DOWN);
    menu.bind(KEY_ENTER, CONFIRM);
    menu.bind(KEY_SPACE, CONFIRM);
    menu.bind(PAD_SOUTH, CONFIRM);
    menu.bind(KEY_ESC, BACK);
    menu.bind(PAD_START, BACK);
    defer { gameplay.bindings.free(); dialog.bindings.free(); menu.bindings.free(); }

    ActionMap map;
    map.push(&gameplay);

    ulong r;
    r = map.resolve(cbit(KEY_W) | cbit(KEY_SPACE));
    print_actions("gameplay: W+SPACE", r);
    assert(r == abit(MOVE_FORWARD) | abit(JUMP));

    r = map.resolve(cbit(PAD_SOUTH) | cbit(PAD_EAST));
    print_actions("gameplay: SOUTH+EAST", r);
    assert(r == abit(JUMP) | abit(INTERACT));

    map.push(&dialog);
    r = map.resolve(cbit(KEY_W) | cbit(KEY_SPACE));
    print_actions("dialog: W+SPACE", r);
    assert(r == abit(MOVE_FORWARD) | abit(DIALOG_NEXT), "dialog must eat SPACE but let W through");

    r = map.resolve(cbit(KEY_E) | cbit(KEY_ESC));
    print_actions("dialog: E+ESC", r);
    assert(r == abit(DIALOG_NEXT) | abit(PAUSE));

    map.push(&menu);
    r = map.resolve(cbit(KEY_W) | cbit(KEY_E) | cbit(KEY_SPACE));
    print_actions("menu: W+E+SPACE", r);
    assert(r == abit(MENU_UP) | abit(CONFIRM), "menu is blocking");

    r = map.resolve(cbit(PAD_START));
    print_actions("menu: START", r);
    assert(r == abit(BACK));

    map.pop();
    map.pop();
    r = map.resolve(0);
    print_actions("gameplay: nothing", r);
    assert(r == 0);

    // Переназначение.
    if (catch err = gameplay.rebind(JUMP, KEY_SPACE, KEY_E))
    {
        io::printn("rebind JUMP SPACE->E: CONFLICT");
        assert(err == CONFLICT);
    }
    else
    {
        unreachable("KEY_E is already bound to INTERACT");
    }
    if (catch err = gameplay.rebind(JUMP, KEY_ENTER, KEY_J))
    {
        io::printn("rebind JUMP ENTER->J: NOT_BOUND");
        assert(err == NOT_BOUND);
    }
    else
    {
        unreachable("JUMP is not bound to ENTER");
    }
    gameplay.rebind(JUMP, KEY_SPACE, KEY_J)!!;
    io::printn("rebind JUMP SPACE->J: ok");
    // Повторная привязка того же действия к тому же control — не конфликт.
    gameplay.rebind(JUMP, PAD_SOUTH, PAD_SOUTH)!!;

    r = map.resolve(cbit(KEY_SPACE));
    print_actions("gameplay: SPACE", r);
    assert(r == 0);
    r = map.resolve(cbit(KEY_J) | cbit(PAD_SOUTH));
    print_actions("gameplay: J+SOUTH", r);
    assert(r == abit(JUMP));

    io::printn("action mapping ok");
}
