// =====================================================================
//  038 · Visibility: `@private`, `@local`, module sections
// =====================================================================
//
//  By default, everything declared in a module (functions, types,
//  global variables, constants) is visible to EVERYONE who imports that
//  module. To hide implementation details, there are visibility
//  attributes:
//
//      fn void helper() @private { ... }  // visible only inside the module
//                                         // (in all of its files)
//      fn void tiny()   @local   { ... }  // visible only in this
//                                         // module SECTION (see below)
//      int counter @private;              // works for global variables
//                                         // and for types too
//
//  It's the equivalent of `static` in C, but more flexible: `@private`
//  isn't limited to one file - a module can be split across several
//  files, and they see each other's private symbols.
//
//  SECTIONS. A single file can contain several `module` declarations -
//  including for different modules or the same one. Each chunk from
//  `module ...;` up to the next `module` is a "section". A section can
//  change the default visibility:
//
//      module bank @private;    // everything below is private...
//      fn void audit() { }      // private
//      fn int peek() @public { } // ...except what's explicitly marked @public
//
//  Imports also only apply within their own section.
//
//  An important detail: in C3 0.8.5, `@local` means "visible only in
//  the current section". Even another section of THE SAME module in
//  THE SAME file won't see such a symbol.
//
//  Sometimes you need to "peek" at private things (for example, in
//  tests or in neighboring modules of the same library):
//  `import bank @public;` makes bank's private (but not @local) symbols
//  visible in this section. Use it deliberately - usually it's better
//  to add a public function.
//
//  This file has three sections: the public part of the bank module,
//  the private part of bank, and the app module with main.
//
//  TASK: fix the three places marked with `// <-`. Don't make public
//  what should stay hidden: `ops` must remain private.
//
module bank;

struct Account
{
    String owner;
    int balance;
}

int ops @private; // how many operations were performed - an implementation detail

fn bool valid_amount(int amount) @private // <- also needed in another section of the module
{
    return amount > 0 && amount <= 10_000;
}

fn bool deposit(Account* a, int amount)
{
    if (!valid_amount(amount)) return false;
    apply(a, amount);
    return true;
}

fn int op_count() => ops;

module bank @private;

// Everything in this section is private by default.
fn void apply(Account* a, int delta)
{
    a.balance += delta;
    ops++;
}

fn bool withdraw(Account* a, int amount) @public // <- must be accessible from outside
{
    if (!valid_amount(amount) || amount > a.balance) return false;
    apply(a, -amount);
    return true;
}

module app;
import std::io;
import bank;

fn void main()
{
    Account acc = { "alice", 0 };
    assert(bank::deposit(&acc, 500));
    assert(!bank::deposit(&acc, -5));
    assert(bank::withdraw(&acc, 120));
    assert(!bank::withdraw(&acc, 1000));
    io::printfn("%s has %d", acc.owner, acc.balance);
    io::printfn("operations: %d", bank::op_count()); // <- the ops variable is private
}
