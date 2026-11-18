1. In `defer (catch err) ...`, the caught error is available under the name given in the parentheses.
2. The "ok" message should only be printed on a successful exit - that's `defer try`.
3. A plain `defer from.balance += amount;` rolls back the transfer ALWAYS, even a successful one. You need `defer catch`.
4. If `check_not_negative(from)!` returns an error, execution never reaches `defer catch to.balance -= amount;`,
   and the recipient keeps the money. Declare the rollback right after changing `to.balance`.
