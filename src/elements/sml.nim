import std/[tables,os]
import ./[wsv]

type
  NodeType = enum
    ntElement, ntAttribute, ntComment

  SmlNode* = ref object
    name*: string
    `type`*: NodeType
    childs*: seq[SmlNode]
    values*: seq[string]
    comment*: string

  SmlDocument* = ref object
    name*: string # root element
    childs*: seq[SmlNode]
    endkeyword*: string

proc newSmlDocumentation*(): SmlDocument
proc parseSmlFile*(fp: string): SmlDocument
proc parseSmlString*(content: string): SmlDocument
proc isElement*(wsvline: WsvLine): bool

proc newSmlDocumentation*(): SmlDocument =
  return SmlDocument()

proc parseSmlFile*(fp: string): SmlDocument =
  return parseSmlString(readFile(fp))
  
proc parseSmlString*(content: string): SmlDocument =
  result = SmlDocument()
  let lines = split(txt, "\n")
  var
    idx = -1
    pendingElement = false
  while idx < len(lines)-1:
    idx.inc()
    let wsvline = parseLine(line)
    if idx == 0:
      if not isElement(wsvline):
        echo("error - malformed SML-Document. First node must be Element")
        system.quit()
      result.name = wsvline.values[0]
      pendingElement = true
      continue

    
proc isElement*(wsvline: WsvLine): bool =
  if len(wsvline.values) == 0:
    echo("error: wsv-line does not contain values")
    system.quit()
  if len(wsvline.values) == 1:
    return true
  else:
    return false
  
  
when isMainModule:
  let wsvdoc = parseWsvFile("test.sml")
  for wsvline in wsvdoc.lines:
    echo wsvline.values

