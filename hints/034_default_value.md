1. In `load_port`, the right side of `??` should be a different error - an empty Optional with `BAD_PORT`
   (remember the suffix from 031).
2. The "default value" operator is written with two question marks: `??`.
3. The right side of `??` is evaluated only when the left side is an error. How many of the two `load_port` calls returned an error?
4. A function with an Optional argument isn't called if the argument holds an error. In which of the two `double_it` calls
   was the argument fine?
