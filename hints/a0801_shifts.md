A variable shift count lives only in `cl`: first `mov rcx, rsi`, then `shl rax, cl`.
`shr` fills the vacated bits with zeros (unsigned division), `sar` with copies of the sign bit (signed).
For the mask: put 1 in a register, shift it by len (the third argument, `rdx`, also via `cl`), subtract 1.
If you're completely stuck: `mov r8d, 1; mov rcx, rdx; shl r8, cl; dec r8; and rax, r8`.
