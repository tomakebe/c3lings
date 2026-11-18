1. In main.c3 the geometry module needs to be imported: `import geometry;` (the shapes submodule comes along by itself).
2. Functions from other modules are called with a prefix of the last part of the module name: `geometry::dot(...)`.
3. In shapes.c3 the constant `PI` is declared in the `geometry` module, not in `geometry::shapes`.
   The parent's types are visible without a prefix, but its constants and functions only with the `geometry::` prefix.
