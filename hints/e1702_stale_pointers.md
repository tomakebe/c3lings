The `think` field holds the address of a function in module v1 - after v1 is unloaded it dangles.
In `spawn` simply don't fill in `think` (keep only x and behavior).
In `update_entities` look the function up through the current module's table: `mod.behaviors[e.behavior](e);`
