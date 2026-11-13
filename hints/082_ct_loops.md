`$for var $i = 1; $i < $n; $i++:` ... `r += a[$i] * b[$i];` ... `$endfor`.
`$foreach $f : $Typeof(s)::members:` и внутри `$if $f.type == int::typeid:` → `total += s.$eval($f.name);`.
Для enum: `$foreach $c : Color::values:` и `io::printfn("%s = %d", $c, $c.ordinal);`.
