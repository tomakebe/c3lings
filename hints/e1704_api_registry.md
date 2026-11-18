`find`: a linear search over `self.slots[0..count)`, comparing `self.slots[i].name() == name`.
`get`: find the slot or create it (`self.create(name, major)`); if `s.major != major` - null,
otherwise `&s.data`. `set`: find or create the slot, update major/minor, copy the bytes:
`s.data[:size] = ((char*)api)[:size];` and `implemented = true`.
`remove`: zero the data (`s.data[..] = 0;`) and `implemented = false`, but don't delete the slot.
