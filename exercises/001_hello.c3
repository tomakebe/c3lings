// =====================================================================
//  001 · Hello, C3!
// =====================================================================
//
//  Welcome to c3lings! Each exercise is a small program that is
//  broken. Your job is to fix it so that it compiles and prints the
//  expected result.
//
//  A C3 program starts with the `main` function:
//
//      fn void main()
//      {
//          ...
//      }
//
//  `fn` is the keyword for declaring a function, and `void` is the
//  return type (we don't return anything).
//
//  To print things, we import the standard library module `std::io`.
//  Functions from other modules are called with the last component of
//  the module name as a prefix: `io::printn(...)` prints a line and
//  then a newline.
//
//  Just like in C, every statement ends with a semicolon.
//
//  TASK: the program should print
//      Hello, C3!
//
import std::io;

fn void main()
{
    io::printn("Hello, C3!")
}
