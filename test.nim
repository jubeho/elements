import std/[tables]
import src/elements

let eb = importCsv("test.csv", ';', 0,1,5)
echo eb.printTree("")
echo eb.elements["2"].childs
