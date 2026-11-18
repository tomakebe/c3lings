// =====================================================================
//  035 · `defer catch`, `defer try`, `defer (catch err)`
// =====================================================================
//
//  In 030 we saw `defer` - code that runs when leaving a scope, no
//  matter how we leave it. With Optionals, a new question appears: are
//  we leaving SUCCESSFULLY or WITH AN ERROR?
//
//  C3 lets you tell these cases apart:
//
//      defer            stmt;  // always
//      defer try        stmt;  // only when leaving WITHOUT an error
//      defer catch      stmt;  // only when leaving WITH an error
//      defer (catch err) stmt; // same, but the error is available as `err`
//
//  The body can also be a block: `defer catch { ...; ... }`.
//
//  "With an error" means the function returns an empty Optional - via
//  `return ERR~;` or via a `!` rethrow.
//
//  The classic use is transactions and rolling back partially done work
//  (in C, people write a ladder of `goto cleanup_N` for this):
//
//      fn void? create_player()
//      {
//          Texture* t = load_texture()!;
//          defer catch free_texture(t);   // in case something breaks later
//          Sound* s = load_sound()!;
//          defer catch free_sound(s);
//          register(t, s)!;
//      }   // success: we free nothing, the resources now "live" in the player
//
//  Just like regular defers, they all run in reverse order, and only
//  the ones that execution actually REACHED. Hence the trap: if a
//  `defer catch` comes AFTER the line with `!` that returned the error,
//  it hasn't been registered and won't run. Declare the rollback right
//  after the action that needs rolling back.
//
//  TASK: the `transfer` function moves money between accounts. If a
//  check fails, the transfer must be fully undone. Fix the four places
//  marked with `// <-`.
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
    defer catch io::printfn("  %d %s -> %s ok", amount, from.name, to.name); // <- only on success

    from.balance -= amount;
    defer from.balance += amount; // <- roll back only on error
    to.balance += amount;
    check_not_negative(from)!;
    defer catch to.balance -= amount; // <- this rollback doesn't always fire
    check_limit(to)!;
}

fn void main()
{
    Account alice = { "alice", 100, 1000 };
    Account bob = { "bob", 50, 120 };

    io::printn("transfers:");
    (void)transfer(&alice, &bob, 30);   // ok
    (void)transfer(&bob, &alice, 500);  // bob doesn't have that much money
    (void)transfer(&alice, &bob, 60);   // bob would go over his limit
    (void)transfer(&alice, &bob, 40);   // ok, exactly at the limit
    (void)transfer(&alice, &bob, 31);   // alice only has 30
    (void)transfer(&bob, &alice, 100);  // ok

    io::printfn("alice=%d bob=%d", alice.balance, bob.balance);
    assert(alice.balance + bob.balance == 150, "money must not appear or vanish");
    assert(alice.balance == 130 && bob.balance == 20);
}
