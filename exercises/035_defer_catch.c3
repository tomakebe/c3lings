// =====================================================================
//  035 · `defer catch`, `defer try`, `defer (catch err)`
// =====================================================================
//
//  В 030 мы видели `defer` — код, который выполнится при выходе из
//  области видимости, как бы мы её ни покидали. Вместе с Optional'ами
//  появляется вопрос: а выходим мы УСПЕШНО или С ОШИБКОЙ?
//
//  C3 позволяет различать эти случаи:
//
//      defer            stmt;  // всегда
//      defer try        stmt;  // только при выходе БЕЗ ошибки
//      defer catch      stmt;  // только при выходе С ошибкой
//      defer (catch err) stmt; // то же, но ошибка доступна как `err`
//
//  Тело может быть и блоком: `defer catch { ...; ... }`.
//
//  «С ошибкой» значит, что функция возвращает пустой Optional — через
//  `return ERR~;` или через проброс `!`.
//
//  Классическое применение — транзакции и откат частично сделанной
//  работы (в C для этого пишут лесенку `goto cleanup_N`):
//
//      fn void? create_player()
//      {
//          Texture* t = load_texture()!;
//          defer catch free_texture(t);   // если дальше что-то сломается
//          Sound* s = load_sound()!;
//          defer catch free_sound(s);
//          register(t, s)!;
//      }   // успех: ничего не освобождаем, ресурсы теперь «живут» в игроке
//
//  Как и обычные, все defer'ы выполняются в обратном порядке и только
//  те, до которых выполнение ДОШЛО. Отсюда ловушка: если `defer catch`
//  стоит ПОСЛЕ строки с `!`, которая и вернула ошибку, — он не
//  зарегистрирован и не выполнится. Объявляйте откат сразу же после
//  действия, которое надо откатывать.
//
//  ЗАДАЧА: функция `transfer` переводит деньги между счетами. Если
//  проверка не прошла, перевод должен быть полностью отменён. Почините
//  четыре места, помеченные `// <-`.
//
import std::io;

excuse INSUFFICIENT_FUNDS, LIMIT_EXCEEDED;

struct Account
{
    String name;
    int balance;
    int limit;
}

fn void? check_not_negative(Account* a)
{
    if (a.balance < 0) return INSUFFICIENT_FUNDS~;
}

fn void? check_limit(Account* a)
{
    if (a.balance > a.limit) return LIMIT_EXCEEDED~;
}

fn void? transfer(Account* from, Account* to, int amount)
{
    defer (catch err) io::printfn("  %d %s -> %s failed: %s", amount, from.name, to.name, ???); // <-
    defer catch io::printfn("  %d %s -> %s ok", amount, from.name, to.name); // <- только при успехе

    from.balance -= amount;
    defer from.balance += amount; // <- откат только при ошибке
    to.balance += amount;
    check_not_negative(from)!;
    defer catch to.balance -= amount; // <- этот откат не всегда срабатывает
    check_limit(to)!;
}

fn void main()
{
    Account alice = { "alice", 100, 1000 };
    Account bob = { "bob", 50, 120 };

    io::printn("transfers:");
    (void)transfer(&alice, &bob, 30);   // ok
    (void)transfer(&bob, &alice, 500);  // у bob нет столько денег
    (void)transfer(&alice, &bob, 60);   // у bob станет больше лимита
    (void)transfer(&alice, &bob, 40);   // ok, ровно лимит
    (void)transfer(&alice, &bob, 31);   // у alice только 30
    (void)transfer(&bob, &alice, 100);  // ok

    io::printfn("alice=%d bob=%d", alice.balance, bob.balance);
    assert(alice.balance + bob.balance == 150, "money must not appear or vanish");
    assert(alice.balance == 130 && bob.balance == 20);
}
