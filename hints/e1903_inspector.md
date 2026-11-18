In the macro wrap the loop body in `$if !$m.has_tag("hidden"): ... $endif`, and after the `$switch` add
`$if $m.has_tag("min"): out[n].ranged = true; out[n].min = $m.get_tag("min"); out[n].max = $m.get_tag("max"); $endif`.
`set`: clamp value if `p.ranged`; the address is `void* at = (char*)self.object + p.offset;`
then `switch (p.kind)`: `*(int*)at = (int)value`, `*(float*)at = (float)value`, `*(bool*)at = value != 0`.
`get` - the same access in the other direction (bool -> 1 or 0).
