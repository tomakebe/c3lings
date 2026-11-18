1. `valid_amount` is marked `@local` - it's visible only in its own section, while `withdraw` lives in another
   section of the bank module. "Visible within the module" is `@private`.
2. `withdraw` is in the `module bank @private;` section, where everything is private by default.
   Mark it explicitly with the `@public` attribute.
3. `bank::ops` is a private variable. The module already has a public function for reading it from outside.
