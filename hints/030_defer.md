1. Right after "open", write `defer io::printfn("close %s", name);`, and delete the
   "close" line at the end of the function — otherwise the file gets "closed" twice.
2. The last declared defer runs first. Swap the two lines.
