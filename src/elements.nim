import std/[tables,strformat,strutils,json]

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

func newElement*(): Element
func newElement*(id, parent: string): Element
func newElement*(id, name, parent: string): Element
func newElement*(id, name, parent: string, childs: seq[string]): Element
func newElement*(id, name, parent: string, childs: seq[string], keyvals: Table[string, seq[string]]): Element
func newElement*(id, name, parent: string, keyvals: Table[string, seq[string]]): Element
func newElementBevy*(): ElementBevy
func newElementBevy*(elem: Element): ElementBevy
func newElementBevy*(elements: seq[Element]): ElementBevy
proc addElement*(eb: ElementBevy, element: Element, checkParent: bool = true)
proc getElement*(eb: ElementBevy, idx: int): Element
proc getElementlevel*(eb: ElementBevy, elementid: string): int
proc getElementlevel*(eb: ElementBevy, element: Element): int
proc getChildElementidents*(eb: ElementBevy, elementid: string): seq[tuple[id, name: string]]
proc getChildElementidents*(eb: ElementBevy, node: Element): seq[tuple[id, name: string]]
proc getSamelevelElementidents*(eb: ElementBevy, elementid: string): seq[tuple[id, name: string]]
proc getSamelevelElementidents*(eb: ElementBevy, element: Element): seq[tuple[id, name: string]]
# proc printTree*(eb: ElementBevy, node: Element, indent: string): string

func newElement*(): Element =
  return Element(
    keyVals: initTable[string, seq[string]](),
  )

func newElement*(id, parent: string): Element =
  return Element(
    id: id,
    parent: parent,
    keyVals: initTable[string, seq[string]](),
  )

func newElement*(id, name, parent: string): Element =
  return Element(
    id: id,
    name: name,
    parent: parent,
    keyVals: initTable[string, seq[string]](),
  )

func newElement*(id, name, parent: string, childs: seq[string]): Element =
  return Element(
    id: id, name: name, parent: parent,
    childs: childs,
    keyVals: initTable[string, seq[string]](),
  )

func newElement*(id, name, parent: string, childs: seq[string], keyvals: Table[string, seq[string]]): Element =
  return Element(id: id, name: name, parent: parent, childs: childs, keyVals: keyvals)
  
func newElement*(id, name, parent: string, keyvals: Table[string, seq[string]]): Element =
  return Element(id: id, name: name, parent: parent, keyVals: keyvals)

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

proc addKeyVal*(elem: Element, key, val: string) =
  if elem.keyVals.hasKey(key):
    elem.keyVals[key].add(val)
  else:
    elem.keyVals[key] = @[val]

proc getElementlevel*(eb: ElementBevy, elementid: string): int =
  return eb.getElementlevel(eb.elements[elementid])
      
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

proc getElement*(eb: ElementBevy, idx: int): Element =
  return eb.elements[eb.elementindex[idx]]
  
proc getRootElementidents*(eb: ElementBevy): seq[tuple[id, name: string]] =
  result = @[]
  for elem in eb.elements.values():
    if elem.parent == "":
      result.add((elem.id, elem.name))

proc getSamelevelElementidents*(eb: ElementBevy, elementid: string): seq[tuple[id, name: string]] =
  return eb.getSamelevelElementidents(eb.elements[elementid])

proc getSamelevelElementidents*(eb: ElementBevy, element: Element): seq[tuple[id, name: string]] =
  result = @[]
  let elemlevel = eb.getElementlevel(element)
  # get all elements, which have this level
  for elem in eb.elements.values():
    if eb.getElementlevel(elem) == elemlevel:
      result.add((elem.id, elem.name))

proc getElementidents*(eb: ElementBevy, level: int): seq[tuple[id, name: string]] =
  result = @[]
  if level < 0:
    return result
  for node in eb.elements.values():
    if eb.getElementlevel(node) == level:
      result.add((node.id, node.name))
      
proc getChildElementidents*(eb: ElementBevy, elementid: string): seq[tuple[id, name: string]] =
  return getChildElementidents(eb, eb.elements[elementid])
  
proc getChildElementidents*(eb: ElementBevy, node: Element): seq[tuple[id, name: string]] =
  result = @[]
  for elementid in node.childs:
    result.add((elementid, eb.elements[elementid].name))

proc printTree*(eb: ElementBevy, elem: Element, indent: string): string =
  result = indent & elem.name & "\n"
  for child in elem.childs:
    result.add(printTree(eb, eb.elements[child], indent & "  "))

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
    
