import std/[tables,strformat,strutils,json,parsecsv]

type
  NonUniqueKeyException* = object of KeyError
  ParentNotFoundException* = object of KeyError
  ParentAlreadyExistsException* = object of RangeDefect

type
  Element* = ref object
    id*: string
    name*: string
    path*: string
    level*: int
    parent*: string # Element-Id
    childs*: seq[string] # Element-Ids
    keyVals*: Table[string, seq[string]] # key: key; val: value or values

  ElementBevy* = ref object
    elementindex*: seq[string] # element-id
    elements*: OrderedTable[string, Element] # key: element-id
    levels*: seq[seq[string]] # dimension1: level, dimension 2: element-ids

func newElement*(id, name, parent: string = "",
                childs: seq[string] = @[],
                keyvals: Table[string, seq[string]] = initTable[string, seq[string]]()): Element =
  return Element(id: id, name: name, parent: parent, childs: childs, keyVals: keyvals)

func newElementBevy*(): ElementBevy =
  return ElementBevy(
    elements: initOrderedTable[string, Element](),
    elementindex: @[],
    levels: @[],
  )
  
func newElementBevy*(elem: Element): ElementBevy =
  return ElementBevy(
    elements: {elem.id: elem}.toOrderedTable(),
    elementindex: @[elem.id],
  )

func newElementBevy*(elements: seq[Element]): ElementBevy {.raises: [KeyError]}=
  for i in 0..<elements.len():
    if i == 0:
      result = newElementBevy(elements[i])
    else:
      if result.elements.hasKey(elements[i].id):
        raise newException(NonUniqueKeyException, fmt("Error: element with id '{elements[i].id}' already in element-bevy"))
      else:
        result.elements[elements[i].id] = elements[i]
        result.elementindex.add(elements[i].id)

proc addElement*(eb: ElementBevy, element: Element, checkParent: bool = true) =
  if (eb.elements.len() > 0) and checkParent:
    if (element.parent == ""):
      raise newException(ParentAlreadyExistsException, "Error: no parent id given - root-element already exists")
    elif not eb.elements.hasKey(element.parent):
      raise newException(ParentNotFoundException, fmt("Error: parent-element with id '{element.parent}' not in element-bevy"))
  if eb.elements.hasKey(element.id):
    raise newException(NonUniqueKeyException, fmt("Error: element with id '{element.id}' already in node-swarm"))
  else:
    eb.elements[element.id] = element
    eb.elementindex.add(element.id)
    if element.parent != "":
      echo "Element->Parent: ", $element.parent
      echo "Parent Element Childs: " & $eb.elements[element.parent].childs
      eb.elements[element.parent].childs.add(element.id)
      

proc addKeyVal*(elem: Element, key, val: string) =
  if elem.keyVals.hasKey(key):
    elem.keyVals[key].add(val)
  else:
    elem.keyVals[key] = @[val]

proc getElement*(eb: ElementBevy, idx: int): Element =
  return eb.elements[eb.elementindex[idx]]

proc getElementlevel*(eb: ElementBevy, element: Element): int =
  let elemparent = element.parent
  if elemparent == "":
    return 0
  var
    foundParent = true
    level = 0
    curParent = elemparent
  while foundParent:
    if eb.elements.hasKey(curParent):
      level.inc()
      curParent = eb.elements[curParent].parent
    else:
      foundParent = false
  return level

proc getElementlevel*(eb: ElementBevy, elementid: string): int =
  return eb.getElementlevel(eb.elements[elementid])
  
proc getRootElementidents*(eb: ElementBevy): seq[tuple[id, name: string]] =
  result = @[]
  for elem in eb.elements.values():
    if elem.parent == "":
      result.add((elem.id, elem.name))

proc getSamelevelElementidents*(eb: ElementBevy, element: Element): seq[tuple[id, name: string]] =
  result = @[]
  let elemlevel = eb.getElementlevel(element)
  # get all elements, which have this level
  for elem in eb.elements.values():
    if eb.getElementlevel(elem) == elemlevel:
      result.add((elem.id, elem.name))

proc getSamelevelElementidents*(eb: ElementBevy, elementid: string): seq[tuple[id, name: string]] =
  return eb.getSamelevelElementidents(eb.elements[elementid])

proc getElementidents*(eb: ElementBevy, level: int): seq[tuple[id, name: string]] =
  result = @[]
  if level < 0:
    return result
  for node in eb.elements.values():
    if eb.getElementlevel(node) == level:
      result.add((node.id, node.name))
      
proc getChildElementidents*(eb: ElementBevy, node: Element): seq[tuple[id, name: string]] =
  result = @[]
  for elementid in node.childs:
    result.add((elementid, eb.elements[elementid].name))

proc getChildElementidents*(eb: ElementBevy, elementid: string): seq[tuple[id, name: string]] =
  return getChildElementidents(eb, eb.elements[elementid])
  
proc printTree*(eb: ElementBevy, elem: Element, indent: string): string =
  result = fmt("{indent}{elem.name} ({elem.id})\n")
  for child in elem.childs:
    echo(fmt("child: '{child}'"))
    result.add(printTree(eb, eb.elements[child], indent & "  "))

proc printTree*(eb: ElementBevy, indent: string): string =
  for elem in eb.elements.values():
    result.add(printTree(eb, elem, indent))

proc validateValues*(elem: Element, valKey, pattern: string,
                     validateProc: proc(value, pattern: string): bool,
                    ):seq[tuple[id, value: string]] =
  if not elem.keyVals.hasKey(valKey):
    return @[]
  result = @[]
  for val in elem.keyVals[valKey]:
    if validateProc(val, pattern):
      result.add((elem.id, val))

proc validateValues*(eb: ElementBevy, valKey, pattern: string,
                     validateProc: proc(value, pattern: string): bool,
                    ):seq[tuple[id, value: string]] =
  result = @[]
  for elem in eb.elements.values():
    result.add(
      validateValues(elem, valKey, pattern, validateProc)
      )
    
proc importCsv*(fp: string, sep: char = ',',
                idCol: int = 0, nameCol: int = -1,
                parentCol, childCol: int = -1): ElementBevy =
  result = newElementBevy()
  var
    headernameIdx = initTable[string, int]() 
    idxHeadername = initTable[int, string]()
  var csv: CsvParser
  
  csv.open(fp, sep)

  csv.readHeaderRow()
  for i in 0..<csv.headers.len():
    headernameIdx[csv.headers[i]] = i
    idxHeadername[i] = csv.headers[i]
  if idCol >= idxHeadername.len():
    raise newException(IndexDefect, "ID col out of range")
  var rowcount = 0
  while csv.readRow():
    let id = csv.row[idCol]
    var
      parent = ""
      name = ""
      childs: seq[string] = @[]
    if nameCol >= 0:
      name = csv.row[nameCol]
    if (parentCol >= 0) and (parentCol < csv.row.len()) :
      parent = csv.row[parentCol]
    if childCol >= 0:
      childs.add(csv.row[childCol])
    var e = newElement(id, name, parent, childs)
    for i in 0..<csv.row.len():
      if i >= idxHeadername.len():
        raise newException(
          IndexDefect,
          fmt("row {rowcount} with column {i}: index out of range: headerIndex-entries: {idxheadername.len()}"))
      e.parent = parent
      e.addKeyVal(idxHeadername[i], csv.row[i])
      
    result.addElement(e, false)
    rowcount.inc()
  csv.close()
