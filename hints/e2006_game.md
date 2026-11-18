`split_rock`: if size <= 1 - return. Copy the asteroid's Transform and Velocity (they're still there until it gets removed
in flush) and call `spawn_rock` twice with the rotated velocities from the doc comment.
`on_collision`: first the `is_doomed` check; then figure out which of the two is the asteroid (via `tags.get(...).kind`)
and which is the "other". Bullet: destroy_later both, score, `rocks_destroyed++`, `split_rock`. Ship: destroy_later
the ship, `has_ship = false`, `lives--`, `respawn_timer = RESPAWN_TICKS`.
At the end of `update`: `if (self.rock_count() == 0) self.spawn_wave();`
