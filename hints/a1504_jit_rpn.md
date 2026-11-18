All binary operations are the same: `e.pop(RCX); e.pop(RAX); <operation>(RAX, RCX); e.push(RAX);` — the right operand is on top, so it is popped first.
NEG: `e.pop(RAX); e.neg(RAX); e.push(RAX);`.
In C3 a case with no body falls through to the next one — each case must have its own body.
