1. A range in a case is written with two dots and includes both ends: `70..79`.
2. Without an explicit `nextcase;`, execution stops after `case 3`. Look at how
   `case 2` does it.
3. In a switch without an expression the FIRST true condition wins. 15 is divisible by both 3 and 5,
   so the `i % 15 == 0` check has to come first.
