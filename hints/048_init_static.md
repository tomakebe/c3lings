1. `build_table` uses `scale`, but with priority 1000 it runs before `load_config` (1100).
   A smaller number means an earlier run. Give `build_table` a priority greater than 1100.
2. A function that must run after main returns is marked with the `@finalizer` attribute.
3. A regular local variable is created anew on every call. You need `static`.
