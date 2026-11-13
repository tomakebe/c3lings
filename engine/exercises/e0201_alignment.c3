// =====================================================================
//  E0201 · Выравнивание и раскладка структур
// =====================================================================
//
//  Сначала прочитайте engine/docs/02_memory.md (раздел 3).
//
//  Любой аллокатор начинается с выравнивания. Для степени двойки a:
//
//      align_up(x, a)   = (x + a - 1) & ~(a - 1)
//      is_aligned(x, a) = (x & (a - 1)) == 0
//      padding(x, a)    = align_up(x, a) - x
//
//  Компилятор раскладывает поля структуры по тому же правилу:
//    * каждое поле кладётся на ближайшее смещение, кратное его
//      выравниванию;
//    * выравнивание структуры = максимум выравниваний полей;
//    * размер структуры округляется вверх до её выравнивания (чтобы
//      в массиве следующий элемент тоже был выровнен).
//
//  В этом упражнении вы напишете маленький «компилятор раскладок» и
//  сверите его с настоящим компилятором через рефлексию C3:
//  `$foreach $m : Type::members: ... $m.offset ... $endforeach`.
//  (Осторожно: `$m.alignment` — это выравнивание поля НА ЕГО МЕСТЕ в
//  структуре, оно может быть больше выравнивания типа; выравнивание
//  самого типа поля — `$m.type.alignment`.)
//
//  А затем — оптимизатор: если отсортировать поля по убыванию
//  выравнивания, дыр становится меньше. C3 (как и C) сам поля не
//  переставляет — порядок полей важен для ABI, это ваша работа.
//
//  ЗАДАЧА: реализуйте align_up, is_aligned, padding, compute_layout
//  (заполнить offsets, size, alignment) и optimal_size (размер при
//  сортировке полей по убыванию выравнивания; сортировка должна быть
//  стабильной — при равном выравнивании сохраняйте исходный порядок).
//
import std::io;

fn usz align_up(usz x, usz a)
{
    // TODO: округлить x вверх до кратного a (a — степень двойки)
    return x;
}

fn bool is_aligned(usz x, usz a)
{
    // TODO
    return true;
}

fn usz padding(usz x, usz a)
{
    // TODO: сколько байт нужно добавить к x, чтобы он стал выровнен
    return 0;
}

struct Field
{
    String name;
    usz size;
    usz align;
}

const int MAX_FIELDS = 16;

struct Layout
{
    usz[MAX_FIELDS] offsets;
    usz size;
    usz alignment;
    usz wasted;        // сумма всех дыр (между полями и в хвосте)
}

fn Layout compute_layout(Field[] fields)
{
    Layout l;
    // TODO: разложите поля как компилятор: offsets[i], alignment, size, wasted
    return l;
}

fn usz optimal_size(Field[] fields)
{
    // TODO: стабильно отсортируйте копию полей по убыванию align
    //       (например, вставками в массив Field[MAX_FIELDS]) и посчитайте
    //       compute_layout(...).size
    return compute_layout(fields).size;
}

// ---------------------------------------------------------------------
// Настоящие структуры и макрос, достающий их раскладку из компилятора.

struct Particle      // плохой порядок полей
{
    bool alive;
    double x;
    char kind;
    float life;
    short flags;
    double y;
}

struct Entity
{
    int id;
    char tag;
    long frame;
    char layer;
}

macro Field[MAX_FIELDS] fields_of($Type, int* count)
{
    Field[MAX_FIELDS] out;
    int n = 0;
    $foreach $m : $Type::members:
        out[n] = { $m.name, $m.size, $m.type.alignment };
        n++;
    $endforeach
    *count = n;
    return out;
}

macro void check_type($Type, String name)
{
    int n;
    Field[MAX_FIELDS] fs = fields_of($Type, &n);
    Layout l = compute_layout(fs[:n]);
    assert(l.size == $Type::size, "%s: size %d, compiler says %d", name, l.size, $Type::size);
    assert(l.alignment == $Type::alignment, "%s: alignment mismatch", name);
    int i = 0;
    $foreach $m : $Type::members:
        assert(l.offsets[i] == $m.offset, "%s.%s: offset %d, compiler says %d", name, $m.name, l.offsets[i], $m.offset);
        i++;
    $endforeach
    io::printf("%-9s size=%2d align=%d wasted=%2d offsets:", name, l.size, l.alignment, l.wasted);
    for (int k = 0; k < n; k++) io::printf(" %s@%d", fs[k].name, l.offsets[k]);
    io::printfn("  -> optimal size %d", optimal_size(fs[:n]));
}

fn void main()
{
    assert(align_up(0, 8) == 0 && align_up(1, 8) == 8 && align_up(8, 8) == 8 && align_up(13, 8) == 16);
    assert(align_up(4095, 4096) == 4096 && align_up(100, 1) == 100);
    assert(is_aligned(64, 16) && !is_aligned(66, 4) && is_aligned(0, 64));
    assert(padding(13, 8) == 3 && padding(16, 16) == 0 && padding(1, 64) == 63);
    io::printn("align_up/is_aligned/padding OK");

    check_type(Particle, "Particle");
    check_type(Entity, "Entity");

    Field[] manual = {
        { "tag", 1, 1 }, { "mask", 8, 8 }, { "id", 2, 2 }, { "vec", 16, 16 }, { "flag", 1, 1 },
    };
    Layout l = compute_layout(manual);
    io::printfn("Manual    size=%d align=%d wasted=%d -> optimal size %d", l.size, l.alignment, l.wasted, optimal_size(manual));
    assert(l.size == 64 && optimal_size(manual) == 32);
    io::printn("layout OK");
}
