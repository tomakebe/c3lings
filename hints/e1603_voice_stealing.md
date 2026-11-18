`play`: first look for an inactive slot. If there isn't one - walk all the voices and pick a victim,
comparing by key (priority, then volume, then start_tick) - whoever is smaller is the victim.
If `victim.priority > priority` - `rejected++` and return `{ INVALID_INDEX, 0 }`. Otherwise `stolen++`.
In the chosen slot: `gen++`, fill in the fields, `start_tick = self.tick`, return `{ (ushort)slot, gen }`.
`is_playing`: the handle is valid, the slot is active and `gen` matches. `stop`: only if `is_playing`, and also `gen++`.
