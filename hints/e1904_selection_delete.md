`delete_selection`: for each handle in the selection that is `w.alive(h)`, store the handle and
`w.slots[h.index].data` in the command, increment `cmd.count`, set the slot's `state = DELETED` (do NOT touch gen).
`undo_delete`: clear the selection; for each saved record restore the slot's `state = ALIVE`
and its data, and add the handle to the selection (`sel.add(h)`).
