// =====================================================================
//  090 · Пользовательские атрибуты и теги
// =====================================================================
//
//  ТЕГИ. Атрибут `@tag("имя", значение)` прикрепляет к объявлению
//  произвольную compile-time пометку — к типу, полю, функции,
//  параметру, переменной. Сам по себе тег ничего не делает: его читает
//  ваш код через рефлексию.
//
//      struct User @tag("table", "users")
//      {
//          int id       @tag("json", "user_id");
//          String password @tag("skip", true);
//      }
//
//      User::has_tag("table")            // true
//      User::get_tag("table")            // "users"
//      $f.has_tag("skip")                // у элемента ::members
//      $reflect(User.id).get_tag("json") // у конкретного поля
//      $reflect(my_func).get_tag("cmd")  // у функции
//
//  Это то же, что аннотации в Java (`@JsonProperty("user_id")`), теги
//  структур в Go (`json:"user_id"`) или атрибуты в C#/Rust
//  (`#[serde(rename = "user_id")]`). Но там их читает рантайм-рефлексия
//  или процедурные макросы, а в C3 — обычный `$foreach` при компиляции,
//  без накладных расходов в рантайме.
//
//  ПОЛЬЗОВАТЕЛЬСКИЕ АТРИБУТЫ — это именованные наборы других атрибутов,
//  объявляемые через `attrmacro`:
//
//      attrmacro @Hot = @inline, @nodiscard;      // набор
//      attrmacro @Json(name) = @tag("json", name); // с параметром
//      attrmacro @Skip = @tag("skip", true);
//      attrmacro @Marker;                          // пустой
//
//      fn int sq(int x) @Hot => x * x;   // то же, что @inline @nodiscard
//      String password @Skip;
//
//  Зачем: дать короткое осмысленное имя частой комбинации и прятать
//  детали (`@Json("login")` читается лучше, чем `@tag("json", "login")`,
//  и если формат тегов поменяется — правка в одном месте). Имя
//  пользовательского атрибута принято писать с заглавной буквы.
//  Пользовательский атрибут разворачивается только в ДРУГИЕ атрибуты —
//  нового поведения он не добавляет; поведение пишете вы, читая теги.
//
//  Классическое применение — сериализация: один макрос `to_json` для
//  всех структур, а теги на полях управляют именами и пропусками
//  (пароль в JSON не попадает!).
//
//  ЗАДАЧА:
//    1. Объявите пользовательские атрибуты `@Json(name)` и `@Skip` так,
//       как описано выше.
//    2. В `to_json` используйте теги: поле с тегом "skip" пропускается,
//       поле с тегом "json" выводится под именем из тега, остальные — под
//       своим именем.
//
import std::io;

attrmacro @Hot = @inline, @nodiscard;
attrmacro @Json(name) = ???;
attrmacro @Skip = ???;

struct User @tag("table", "users")
{
    int id @Json("user_id");
    String name @Json("login");
    String password @Skip;
    int age;
}

struct Item @tag("table", "items")
{
    String title;
    int price @Json("price_cents");
    bool internal_flag @Skip;
}

fn int sq(int x) @Hot => x * x;

fn void greet() @tag("cmd", "hello") {}

macro void to_json(value)
{
    io::print("{");
    var $first = true;
    $foreach $f : $Typeof(value)::members:
        // TODO: пропускать поля с тегом "skip", брать имя из тега "json"
        $if !$first:
            io::print(", ");
        $endif
        $first = false;
        io::printf("\"%s\": ", $f.name);
        $if $f.type == String::typeid:
            io::printf("\"%s\"", value.$eval($f.name));
        $else
            io::printf("%s", value.$eval($f.name));
        $endif
    $endforeach
    io::printn("}");
}

macro void save($Type, value)
{
    io::printf("INSERT INTO %s: ", $Type::get_tag("table"));
    to_json(value);
}

fn void main()
{
    User u = { 7, "neo", "secret", 30 };
    Item it = { "sword", 1500, true };

    save(User, u);
    save(Item, it);

    io::printfn("User has table tag: %s, Item has 'cmd' tag: %s",
                User::has_tag("table"), Item::has_tag("cmd"));
    io::printfn("greet is command '%s'", $reflect(greet).get_tag("cmd"));
    io::printfn("password skipped: %s", $reflect(User.password).has_tag("skip"));
    io::printfn("sq(9) = %d", sq(9));
}
