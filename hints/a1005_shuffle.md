Reversal: result lane 0 takes element 3, lane 1 takes 2, ... In imm, lane 0 is the low 2 bits: 0b00_01_10_11.
pshufb mask for BGRA: in each group of four bytes, swap bytes 0 and 2: 2,1,0,3, 6,5,4,7, ...
Loop: `movdqu xmm0, [rdi + rax*4]; pshufb xmm0, xmm1; movdqu [rdi + rax*4], xmm0`, step 4 pixels, while rax < count - 3.
Tail: load a pixel into edx, `bswap edx` reverses all 4 bytes, and `ror edx, 8` puts alpha back in place.
