// =====================================================================
//  e1903 · Инспектор свойств на рефлексии
// =====================================================================
//
//  Панель «Inspector» в редакторе показывает поля выбранного объекта и
//  даёт их менять. Писать UI вручную для каждого компонента — тупик:
//  компонентов сотни, и они постоянно меняются. Поэтому движки
//  описывают поля ДАННЫМИ — «дескрипторами свойств»:
//
//      { name = "x", offset = 0, kind = FLOAT, min = -100, max = 100 }
//
//  и пишут ОДИН инспектор, одну сериализацию, одну систему undo, одну
//  анимацию свойств, один сетевой репликатор — всё поверх дескрипторов.
//
//  Откуда взять дескрипторы:
//    * C++: макросы-регистраторы (Unreal UPROPERTY + Unreal Header Tool
//      — отдельный генератор кода!), RTTR, ручные таблицы;
//    * C3: рефлексия ВРЕМЕНИ КОМПИЛЯЦИИ — бесплатно, без генераторов:
//
//      $foreach $m : Transform::members:
//          $m.name, $m.offset, $m.type (typeid), $m.has_tag("min"),
//          $m.get_tag("min")
//      $endforeach
//
//  Метаданные для редактора (диапазон ползунка, «скрыть», подсказка)
//  вешаются на поля тегами: `float x @tag("min", -100) @tag("max", 100);`
//
//  Записать значение по дескриптору — это запись по адресу
//  (char*)obj + offset с приведением к типу по kind. Именно так
//  работает любой инспектор, сериализатор и undo «по свойству»:
//  команда SetProperty{object, property_index, old, new}.
//
//  ЗАДАЧА: в макросе @describe пропускайте поля с тегом "hidden" и
//  заполняйте диапазон из тегов "min"/"max"; реализуйте Inspector.set
//  (с ограничением диапазоном) и Inspector.get.
//
import std::io;

enum PropKind
{
    INT,
    FLOAT,
    BOOL,
}

struct Prop
{
    String name;
    usz offset;
    PropKind kind;
    bool ranged;
    double min;
    double max;
}

macro usz @describe($Type, Prop[] out)
{
    usz n = 0;
    $foreach $m : $Type::members:
        // TODO: пропустить поля с тегом "hidden" ($if !$m.has_tag("hidden"): ... $endif)
        out[n] = { .name = $m.name, .offset = $m.offset };
        $switch $m.type:
            $case int::typeid: out[n].kind = INT;
            $case float::typeid: out[n].kind = FLOAT;
            $case bool::typeid: out[n].kind = BOOL;
            $default: $error "unsupported property type";
        $endswitch
        // TODO: если есть тег "min" — ranged = true, min/max из тегов
        n++;
    $endforeach
    return n;
}

struct Inspector
{
    Prop[16] props;
    usz count;
    void* object;
}

macro Inspector @inspect(obj)
{
    Inspector ins = { .object = obj };
    ins.count = @describe($Typeof(*obj), &ins.props);
    return ins;
}

fn Prop*? Inspector.find(&self, String name)
{
    foreach (&p : self.props[:self.count]) if (p.name == name) return p;
    return NOT_FOUND~;
}

// Записать значение (числа для bool: 0 = false, иначе true).
// Для ranged-свойств — ограничить [min, max]. int — отбрасыванием дроби.
fn void? Inspector.set(&self, String name, double value)
{
    Prop* p = self.find(name)!;
    // TODO: clamp, адрес = (char*)self.object + p.offset, запись по kind
    (void)p;
    (void)value;
}

fn double? Inspector.get(&self, String name)
{
    Prop* p = self.find(name)!;
    // TODO
    (void)p;
    return 0;
}

// ---------------------------------------------------------------------
// Ниже ничего менять не нужно.

excuse NOT_FOUND;

struct Transform
{
    float x @tag("min", -100) @tag("max", 100);
    float y @tag("min", -100) @tag("max", 100);
    float scale @tag("min", 0.1) @tag("max", 10);
    int layer @tag("min", 0) @tag("max", 7);
    bool visible;
    int cached_hash @tag("hidden", true);    // служебное поле, не для UI
}

struct Light
{
    float intensity @tag("min", 0) @tag("max", 1000);
    int color;
    bool shadows;
}

fn void Inspector.draw(&self, String title)
{
    io::printfn("[%s]", title);
    foreach (p : self.props[:self.count])
    {
        double v = self.get(p.name)!!;
        switch (p.kind)
        {
            case INT: io::printf("  %-10s %d", p.name, (int)v);
            case FLOAT: io::printf("  %-10s %.2f", p.name, v);
            case BOOL: io::printf("  %-10s %s", p.name, v != 0);
        }
        if (p.ranged) io::printf("   [%.1f .. %.1f]", p.min, p.max);
        io::printn();
    }
}

fn void main()
{
    Transform t = { 1, 2, 1, 0, true, 12345 };
    Inspector ins = @inspect(&t);
    assert(ins.count == 5, "скрытое поле не должно попасть в инспектор");
    assert(ins.props[3].ranged && ins.props[3].max == 7.0, "диапазон из тегов");

    ins.set("x", 42.5)!!;
    ins.set("y", -1000)!!;        // ограничится -100
    ins.set("layer", 9.7)!!;      // ограничится 7
    ins.set("scale", 2.5)!!;
    ins.set("visible", 0)!!;
    assert(t.x == 42.5f && t.y == -100.0f && t.layer == 7 && !t.visible);
    assert(t.cached_hash == 12345);
    if (catch err = ins.set("cached_hash", 1)) io::printfn("cached_hash: %s", err);
    ins.draw("Transform");

    // тот же инспектор работает для любого типа без единой строчки UI-кода
    Light l = { 300, 0xFFAA00, false };
    Inspector li = @inspect(&l);
    li.set("intensity", 5000)!!;
    li.set("shadows", 1)!!;
    li.set("color", 255)!!;
    assert(l.intensity == 1000.0f && l.shadows && l.color == 255);
    li.draw("Light");
}
