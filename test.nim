import std/[tables]
import src/elements

let eb = importCsv("test.csv", ';', 0,1,5, -1, true)
echo eb.printTree("")
for e in eb.elements.values():
  echo e.path
