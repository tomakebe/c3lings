// =====================================================================
//  036 · Built-in errors, `switch` on errors, error descriptions
// =====================================================================
//
//  You don't have to declare your own error for every case. The
//  standard library already contains common errors marked `@builtin` -
//  they can be written without a module prefix (see lib/std/core/builtin.c3):
//
//      NOT_FOUND          the element isn't in the collection
//      NO_MORE_ELEMENT    the iterator is exhausted / out of bounds
//      TYPE_MISMATCH      a type conversion failed
//      CAPACITY_EXCEEDED  a bounded container is full
//      NOT_IMPLEMENTED    the feature isn't available
//      TIMEOUT            time ran out / retry limit exceeded
//
//  Other errors live in their own modules and are written with a prefix:
//  `io::FILE_NOT_FOUND`, `io::EOF`, `string::MALFORMED_INTEGER`,
//  `string::EMPTY_STRING`, `mem::OUT_OF_MEMORY`...
//
//  `fault` is an ordinary pointer-sized value type:
//  * it can be stored in variables, arrays, struct fields;
//  * compared with `==`;
//  * the zero `fault` value (the default) means "no error"
//    and behaves like false in conditions: `if (f) ...`;
//  * it has a `.description` field - a string of the form "module::NAME",
//    e.g. "builtin::NOT_FOUND" or "io::EOF". For the "empty" fault
//    it's an empty string. Printing a fault with `%s` gives the same thing.
//
//  A `switch` on a fault works just like on an enum: the labels are
//  error values, `break` is implicit, an empty case "falls through" to
//  the next one:
//
//      switch (err)
//      {
//          case io::FILE_NOT_FOUND:
//          case io::NO_PERMISSION:  show("cannot open");   // both errors land here
//          case io::EOF:            show("file truncated");
//          default:                 show("something else");
//      }
//
//  A practical tip: `.description` is for logs and debugging; it's
//  better to show the user your own clear text.
//
//  TASK: fix the three places marked with `// <-`.
//
import std::io;

struct Inventory
{
    String[3] names;
    int[3] counts;
    usz len;
}

fn void? Inventory.add(&self, String name, String count_text)
{
    if (self.len == self.names.len) return CAPACITY_EXCEEDED~;
    int count = count_text.to_int()!;
    self.names[self.len] = name;
    self.counts[self.len] = count;
    self.len++;
}

fn int? Inventory.count_of(&self, String name)
{
    for (usz i = 0; i < self.len; i++)
    {
        if (self.names[i] == name) return self.counts[i];
    }
    return NOT_FOUND~; // <- the built-in "no such element" error
}

fn String explain(fault f)
{
    switch (f)
    {
        case CAPACITY_EXCEEDED: return "inventory is full";
        case NOT_FOUND: return "no such item";
        case string::EMPTY_STRING: // <- both number-parsing errors
        case string::MALFORMED_INTEGER: return "bad number";
        default: return "unexpected error";
    }
}

fn void main()
{
    Inventory inv;
    fault[6] results;
    results[0] = @catch(inv.add("sword", "1"));
    results[1] = @catch(inv.add("arrow", "x20"));
    results[2] = @catch(inv.add("arrow", "20"));
    results[3] = @catch(inv.add("bread", ""));
    results[4] = @catch(inv.add("bread", "3"));
    results[5] = @catch(inv.add("shield", "1"));

    foreach (i, f : results)
    {
        if (!f) // <- "no error"
        {
            io::printfn("add #%d: ok", i);
            continue;
        }
        io::printfn("add #%d: %s (%s)", i, explain(f), f.description);
    }

    foreach (name : (String[]){ "arrow", "potion" })
    {
        int? n = inv.count_of(name);
        if (catch err = n)
        {
            io::printfn("%s: %s", name, explain(err));
            continue;
        }
        io::printfn("%s: %d", name, n);
    }
    assert(@catch(inv.count_of("potion")) == NOT_FOUND);
}
