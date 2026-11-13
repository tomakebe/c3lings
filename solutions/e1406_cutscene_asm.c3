// =====================================================================
//  e1406 · Итог главы: ассемблер скриптов и катсцена
// =====================================================================
//
//  Сначала прочитайте engine/docs/14_scripting.md целиком.
//
//  Собираем всё вместе. Дизайнер пишет катсцену ТЕКСТОМ:
//
//      .global hero
//              push 0
//              call spawn          ; hero = spawn(0)
//              store hero
//      walk:
//              load hero
//              push 2
//              call move
//              pop
//              wait 1              ; сопрограмма уступает кадр
//              ...
//              jnz walk
//              jmp door            ; ссылка ВПЕРЁД на метку
//
//  а движок собирает из неё байткод и крутит несколько таких скриптов
//  параллельно через планировщик (как в e1404), с нативами (e1402) и
//  бюджетом (e1401). Вам осталось написать ядро ассемблера.
//
//  Как работает ассемблер:
//    * строка = [метка:] | [мнемоника [операнд]] [; комментарий];
//    * имена глобальных (`load hero`) и нативов (`call move`) превращаются
//      в индексы ЗДЕСЬ, на этапе сборки — в рантайме никаких строк;
//    * метка запоминает текущий адрес (self.len) — адрес СЛЕДУЮЩЕЙ
//      инструкции;
//    * переход на уже известную метку сразу получает адрес; на ещё не
//      встреченную — записывается «fixup» (куда вписать и какую метку
//      ждём), а в конце assemble() все fixup'ы разрешаются. Это
//      backpatching — однопроходная сборка с заплатками, как в
//      настоящих ассемблерах и в однопроходном компиляторе clox;
//    * любая ошибка возвращается как fault, а в self.error_line остаётся
//      номер строки — дизайнеру нужно сообщение «строка 2: UNKNOWN_OP»,
//      а не падение игры.
//
//  ЗАДАЧА (в Asm.line, Asm.emit_jump, Asm.assemble):
//    * определение метки "name:" (DUPLICATE_LABEL при повторе);
//    * операнды load/store (global_index), call (native_index),
//      jmp/jnz (через emit_jump);
//    * emit_jump: известная метка -> адрес, иначе fixup + emit(op, -1);
//    * разрешение fixup'ов в конце assemble() (UNKNOWN_LABEL, с номером
//      строки, где был переход).
//
module cutscene;
import std::io;

excuse UNKNOWN_OP, UNKNOWN_LABEL, UNKNOWN_NATIVE, UNKNOWN_GLOBAL, BAD_NUMBER,
       DUPLICATE_LABEL, TOO_BIG, STACK_OVERFLOW, STACK_UNDERFLOW, BUDGET_EXCEEDED;

// ================================================================ bytecode

enum Op : char { PUSH, POP, LOAD, STORE, ADD, JMP, JNZ, CALL, WAIT, SAY, END }
struct Instr { Op op; int arg; }

const int MAX_CODE = 64;
const int MAX_NAMES = 8;

// ================================================================ natives

struct Stage
{
    long now;
    int[4] actor_x;
    int actors;
    bool door_open;
}

alias NativeFn = fn int?(int[] args, Stage* st);
struct Native { String name; int arity; NativeFn func; }

fn int? n_spawn(int[] a, Stage* st)
{
    int h = st.actors++;
    st.actor_x[h] = a[0];
    io::printfn("t=%d   [stage] actor %d appears at x=%d", st.now, h, a[0]);
    return h;
}

fn int? n_move(int[] a, Stage* st)
{
    st.actor_x[a[0]] += a[1];
    io::printfn("t=%d   [stage] actor %d walks to x=%d", st.now, a[0], st.actor_x[a[0]]);
    return st.actor_x[a[0]];
}

fn int? n_open_door(int[] a, Stage* st)
{
    st.door_open = true;
    io::printfn("t=%d   [stage] door opens", st.now);
    return 1;
}

const Native[] NATIVES = {
    { "spawn", 1, &n_spawn },
    { "move", 2, &n_move },
    { "open_door", 0, &n_open_door },
};

// ================================================================ assembler

// Ссылка вперёд на метку, которую ещё не видели: «когда узнаешь адрес
// метки name, впиши его в code[at].arg».
struct Fixup
{
    String label;
    int at;
    int line;
}

struct Asm
{
    Instr[MAX_CODE] code;
    int len;
    String[MAX_NAMES] strings;
    int nstrings;
    String[MAX_NAMES] globals;
    int nglobals;
    String[MAX_NAMES] label_names;
    int[MAX_NAMES] label_pos;
    int nlabels;
    Fixup[MAX_NAMES] fixups;
    int nfixups;
    int error_line;   // строка (с 1), на которой случилась ошибка
}

fn void? Asm.emit(&self, Op op, int arg = 0)
{
    if (self.len >= MAX_CODE) return TOO_BIG~;
    self.code[self.len++] = { op, arg };
}

fn int? parse_number(String s)
{
    if (try n = s.to_int()) return n;
    return BAD_NUMBER~;
}

fn int? Asm.global_index(&self, String name)
{
    for (int i = 0; i < self.nglobals; i++) if (self.globals[i] == name) return i;
    return UNKNOWN_GLOBAL~;
}

fn int? native_index(String name)
{
    foreach (i, n : NATIVES) if (n.name == name) return (int)i;
    return UNKNOWN_NATIVE~;
}

fn int? Asm.label_index(&self, String name)
{
    for (int i = 0; i < self.nlabels; i++) if (self.label_names[i] == name) return i;
    return UNKNOWN_LABEL~;
}

// Переход на метку: если метка уже известна — сразу адрес, иначе
// записываем fixup и разрешим его в конце (backpatching).
fn void? Asm.emit_jump(&self, Op op, String label, int line)
{
    if (try li = self.label_index(label))
    {
        self.emit(op, self.label_pos[li])!;
        return;
    }
    if (self.nfixups >= MAX_NAMES) return TOO_BIG~;
    self.fixups[self.nfixups++] = { label, self.len, line };
    self.emit(op, -1)!;
}

fn void? Asm.line(&self, String text)
{
    // 1) отрезать комментарий и пробелы
    if (try c = text.index_of_char(';')) text = text[:c];
    text = text.trim();
    if (text.len == 0) return;

    // 2) метка "name:"
    if (text.ends_with(":"))
    {
        String name = text[:text.len - 1];
        if (@ok(self.label_index(name))) return DUPLICATE_LABEL~;
        if (self.nlabels >= MAX_NAMES) return TOO_BIG~;
        self.label_names[self.nlabels] = name;
        self.label_pos[self.nlabels] = self.len;
        self.nlabels++;
        return;
    }

    // 3) мнемоника и операнд
    String op = text;
    String rest = "";
    if (try sp = text.index_of_char(' '))
    {
        op = text[:sp];
        rest = text[sp..].trim();
    }

    switch (op)
    {
        case ".global":
            if (self.nglobals >= MAX_NAMES) return TOO_BIG~;
            self.globals[self.nglobals++] = rest;
        case "push": self.emit(PUSH, parse_number(rest)!)!;
        case "pop": self.emit(POP)!;
        case "add": self.emit(ADD)!;
        case "end": self.emit(END)!;
        case "wait": self.emit(WAIT, parse_number(rest)!)!;
        case "say":
            if (self.nstrings >= MAX_NAMES) return TOO_BIG~;
            self.strings[self.nstrings] = rest;
            self.emit(SAY, self.nstrings++)!;
        case "load": self.emit(LOAD, self.global_index(rest)!)!;
        case "store": self.emit(STORE, self.global_index(rest)!)!;
        case "call": self.emit(CALL, native_index(rest)!)!;
        case "jmp": self.emit_jump(JMP, rest, self.error_line)!;
        case "jnz": self.emit_jump(JNZ, rest, self.error_line)!;
        default: return UNKNOWN_OP~;
    }
}

fn void? Asm.assemble(&self, String source)
{
    *self = {};
    String[] lines = source.tsplit("\n");
    foreach (i, l : lines)
    {
        self.error_line = (int)i + 1;
        self.line(l)!;
    }
    // разрешаем ссылки вперёд
    for (int i = 0; i < self.nfixups; i++)
    {
        Fixup f = self.fixups[i];
        self.error_line = f.line;
        int li = self.label_index(f.label)!;
        self.code[f.at].arg = self.label_pos[li];
    }
    self.error_line = 0;
}

// ================================================================ runtime

enum State : char { READY, WAITING, DONE, FAULTED }

struct Script
{
    String name;
    Asm prog;
    int pc;
    int[8] stack;
    int sp;
    int[MAX_NAMES] globals;
    State state;
    long wake;
}

fn void? Script.push(&self, int v)
{
    if (self.sp >= 8) return STACK_OVERFLOW~;
    self.stack[self.sp++] = v;
}

fn int? Script.pop(&self)
{
    if (self.sp <= 0) return STACK_UNDERFLOW~;
    return self.stack[--self.sp];
}

fn void? Script.resume(&self, Stage* st)
{
    for (int steps = 0; steps < 100; steps++)
    {
        Instr ins = self.prog.code[self.pc++];
        switch (ins.op)
        {
            case PUSH: self.push(ins.arg)!;
            case POP: self.pop()!;
            case LOAD: self.push(self.globals[ins.arg])!;
            case STORE: self.globals[ins.arg] = self.pop()!;
            case ADD: self.push(self.pop()! + self.pop()!)!;
            case JMP: self.pc = ins.arg;
            case JNZ: if (self.pop()! != 0) self.pc = ins.arg;
            case CALL:
                Native n = NATIVES[ins.arg];
                if (self.sp < n.arity) return STACK_UNDERFLOW~;
                int base = self.sp - n.arity;
                int r = n.func(self.stack[base:n.arity], st)!;
                self.sp = base;
                self.push(r)!;
            case WAIT:
                self.state = WAITING;
                self.wake = st.now + (ins.arg < 1 ? 1 : ins.arg);
                return;
            case SAY:
                io::printfn("t=%d %s: %s", st.now, self.name, self.prog.strings[ins.arg]);
            case END:
                self.state = DONE;
                return;
        }
    }
    return BUDGET_EXCEEDED~;
}

fn void run_all(Script*[] scripts, Stage* st)
{
    while (true)
    {
        bool busy = false;
        foreach (s : scripts)
        {
            if (s.state == WAITING && st.now >= s.wake) s.state = READY;
            if (s.state == READY)
            {
                if (catch err = s.resume(st))
                {
                    s.state = FAULTED;
                    io::printfn("t=%d %s: FAULT %s", st.now, s.name, err);
                }
            }
            if (s.state == READY || s.state == WAITING) busy = true;
        }
        if (!busy) return;
        st.now++;
        assert(st.now < 100);
    }
}

// ================================================================ main

const String INTRO = `; intro cutscene
.global hero
.global steps

        push 0
        call spawn          ; hero = spawn(0)
        store hero
        say hero enters
        push 3
        store steps
walk:
        load hero
        push 2
        call move
        pop
        wait 1
        load steps
        push -1
        add
        store steps
        load steps
        jnz walk
        jmp door            ; forward reference
        say this line is skipped
door:
        call open_door
        pop
        say the door creaks
        wait 2
        say fin
        end
`;

const String CAMERA = `
        say fade in
        wait 2
        say shake
        wait 3
        say fade out
        end
`;

fn void expect_error(String src, fault expected, int line)
{
    Asm a;
    if (catch err = a.assemble(src))
    {
        io::printfn("asm error: %s at line %d", err, a.error_line);
        assert(err == expected, "expected %s, got %s", expected, err);
        assert(a.error_line == line, "expected line %d, got %d", line, a.error_line);
        return;
    }
    unreachable("assembler accepted a broken program");
}

fn void main()
{
    // ошибки ассемблера: тип и номер строки
    expect_error("push 1\njump walk\n", UNKNOWN_OP, 2);
    expect_error("push 1x", BAD_NUMBER, 1);
    expect_error(".global a\nload b", UNKNOWN_GLOBAL, 2);
    expect_error("\n\ncall fly", UNKNOWN_NATIVE, 3);
    expect_error("x:\n  jmp y ; nowhere\nend", UNKNOWN_LABEL, 2);
    expect_error("x:\nx:", DUPLICATE_LABEL, 2);

    Script intro = { .name = "intro" };
    Script camera = { .name = "camera" };
    intro.prog.assemble(INTRO)!!;
    camera.prog.assemble(CAMERA)!!;
    io::printfn("intro: %d instructions, %d labels, camera: %d instructions",
                intro.prog.len, intro.prog.nlabels, camera.prog.len);
    assert(intro.prog.len == 25 && intro.prog.nlabels == 2 && camera.prog.len == 6);
    assert(intro.prog.code[16].op == JNZ && intro.prog.code[16].arg == 6);
    assert(intro.prog.code[17].op == JMP && intro.prog.code[17].arg == 19);

    Stage stage;
    Script*[2] all = { &intro, &camera };
    run_all(&all, &stage);

    assert(intro.state == DONE && camera.state == DONE);
    assert(stage.door_open && stage.actor_x[0] == 6);
    io::printfn("cutscene finished at t=%d", stage.now);
}
