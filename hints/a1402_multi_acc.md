In the loop body: `add r9, [rdi + rcx*8 + 16]` and `add r10, [rdi + rcx*8 + 24]`.
After the loop, add r8, r9, r10 into rax (preferably in pairs: `add rax, r8; add r9, r10; add rax, r9`).
Tail: an ordinary one-element-at-a-time loop while rcx < n.
