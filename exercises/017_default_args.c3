// =====================================================================
//  017 · Default arguments and named arguments
// =====================================================================
//
//  DEFAULT ARGUMENTS
//  A parameter can be given a default value. Then you can leave it out
//  when calling:
//
//      fn int damage(int base, int multiplier = 2) => base * multiplier;
//
//      damage(10);       // 20 — multiplier takes its default
//      damage(10, 3);    // 30
//
//  C has nothing like this — there you write several functions or pass
//  "magic" values like -1.
//
//  NAMED ARGUMENTS
//  When calling, you can name the parameter: `name: value`. This makes
//  the call self-documenting and lets you skip default parameters in
//  the middle of the list:
//
//      fn void open(String title, int width = 800, int height = 600) { ... }
//
//      open("Editor", height: 300);        // width = 800 by default
//      open(title: "Game", width: 1024);
//
//  The rules (enforced by the compiler):
//  * positional arguments come first, then named ones;
//  * named arguments must come IN THE SAME ORDER as the parameters in
//    the declaration ("Named arguments must always be declared in
//    order"). You can't reorder them — this guarantees that arguments
//    are always evaluated in the order they appear in the code.
//
//  TASK: fix the three places marked `// <-`. The program should print:
//
//      Game: 800x600 windowed
//      Editor: 800x300 windowed
//      Tiny: 320x240 windowed
//      Movie: 1920x600 fullscreen
//      damage: 20 30
//
import std::io;

fn void open_window(String title, int width = 800, int height = 600, bool fullscreen = false)
{
    io::printfn("%s: %dx%d %s", title, width, height, fullscreen ? "fullscreen" : "windowed");
}

fn int damage(int base, int multiplier) => base * multiplier;   // <- multiplier defaults to 2

fn void main()
{
    open_window("Game");
    open_window("Editor", ???);                          // <- height 300, default width
    open_window("Tiny", 320, 240);
    open_window("Movie", fullscreen: true, width: 1920); // <- order of the named arguments

    io::printfn("damage: %d %d", damage(10), damage(10, 3));
}
