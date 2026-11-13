`try_advance`: `while (self.tick <= target && self.have[self.tick][0] && self.have[self.tick][1])` —
`self.sim.step(self.inputs[self.tick])`, сохраните `self.checksums[self.tick] = self.sim.checksum()`, `self.tick++`.
После цикла: если `self.tick <= target` — `stalls++`.
`checksum`: FNV-1a — `h = 2166136261`, для каждого поля `h = (h ^ (uint)value) * 16777619`.
