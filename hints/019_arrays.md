1. To have the compiler count the size itself, write `*` instead of a number: `int[*]`.
2. `doubled` receives a COPY of the array and returns a new array. Assign the result:
   `scores = doubled(scores);`.
3. `backup` was copied before the doubling and hasn't changed since.
