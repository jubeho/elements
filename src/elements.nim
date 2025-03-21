import std/[tables,strformat,strutils,json,parsecsv,sequtils]
# import xl

const
  pathseparator = "/"
  valsJoinString = "|>"
  keyMapTrueVals = @["j", "y", "ja", "Ja", "yes"]

type
  NonUniqueKeyException* = object of KeyError
  ParentNotFoundException* = object of KeyError
  ParentAlreadyExistsException* = object of RangeDefect
  ExcelReadError* = object of IOError
  KeyNotInElementKeyVals* = object of KeyError
  ElementIdNotInElementBevy* = object of KeyError

type
  Element* = ref object
    id*: string
    name*: string
    path*: string
    level*: int
    parent*: string # Element-Id
      ## the parents-element elemen-id
    childs*: seq[string] # Element-Ids
    keyVals*: OrderedTable[string, seq[string]] # key: key; val: value or values

  ElementBevy* = ref object
    elementindex*: seq[string] # element-id
    elements*: OrderedTable[string, Element] # key: element-id
    levels*: seq[seq[string]] # dimension1: level, dimension 2: element-ids

func newElement*(id, name, parent: string = "",
                childs: seq[string] = @[],
                keyvals: OrderedTable[string, seq[string]] = initOrderedTable[string, seq[string]]()): Element =
  return Element(id: id, name: name, parent: parent, childs: childs, keyVals: keyvals)

func newElementBevy*(makeroot: bool = false): ElementBevy =
  result = ElementBevy(
    elements: initOrderedTable[string, Element](),
    elementindex: @[],
    levels: @[],
  )
  if makeroot:
    var e = newElement("/", "root", "")
    e.path = "/"
    e.level = 0
    result.elements["/"] = e
    result.elementindex.add("/")
  
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
    if element.parent == "":
      if eb.elements.hasKey("/"):
        eb.elements["/"].childs.add(element.id)
      element.path = pathseparator & element.id
      element.level = 0
    else:
      eb.elements[element.parent].childs.add(element.id)
      element.path = eb.elements[element.parent].path & pathseparator & element.id
      element.level = eb.elements[element.parent].level + 1
    eb.elements[element.id] = element
    eb.elementindex.add(element.id)

proc addKeyVal*(elem: Element, key, val: string) =
  if elem.keyVals.hasKey(key):
    elem.keyVals[key].add(val)
  else:
    elem.keyVals[key] = @[val]

proc getVals*(elem: Element, key: string): string =
  ## returns concatenated vals from Element.keyVals->key if key exists
  ## otherwise returns ""
  ## so you have check the key before...
  if elem.keyVals.hasKey(key):
    return elem.keyVals[key].join(valsJoinString)
  else:
    return ""
  
proc delElement*(eb: var ElementBevy, elementId: string) =
  if not eb.elements.hasKey(elementId):
    raise newException(ElementIdNotInElementBevy, fmt("element-id '{elementId}' not in element-bevy"))
  let
    elemIdx = eb.elementindex.find(elementId)
    parent = eb.elements[elementId].parent
    childs = eb.elements[elementId].childs
  for child in childs:
    if not eb.elements.hasKey(child):
      raise newException(ElementIdNotInElementBevy, fmt("child-id '{child}' not in element-bevy"))
    # TODO: chek if there is a parent and log it
    eb.elements[child].parent = ""
  if parent != "":
    if not eb.elements.hasKey(parent):
      raise newException(ElementIdNotInElementBevy, fmt("parent-id '{parent}' not in element-bevy"))
    var newchilds: seq[string] = @[]
    for child in eb.elements[parent].childs:
      if child == parent:
        continue
      else:
        newchilds.add(child)
    eb.elements[parent].childs = newchilds
  if elemIdx >= 0:
    eb.elementindex.delete(elemIdx..elemIdx)
  eb.elements.del(elementId)

proc getUnionKeys*(eb: ElementBevy): (OrderedTable[string, int], seq[string]) =
  ## lists all keys from elements.keyVals into a table and a sequence
  ## table holds keyname and occurence, sequence only the keynames
  var
    keyOccurence = initOrderedTable[string, int]()
    keys: seq[string] = @[]
  for e in eb.elements.values():
    for key in e.keyVals.keys():
      if keyOccurence.hasKey(key):
        keyOccurence[key] = keyOccurence[key] + 1
      else:
        keyOccurence[key] = 1
        keys.add(key)
  return (keyOccurence, keys)

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

proc getAllVals*(eb: ElementBevy, key: string): (OrderedTable[string, int], seq[string], seq[string]) =
  ## collects all values from given key.
  ## returns
  ## - union-Table with values and occurences in ElementBevy
  ## - uniqueVals: this values are unique in ElementBevy for the key
  ## - nonuniqueVals: values, which are more than once in ElementBevy for the key
  ## e.g.: i get results from all the values in all elements for a key "Streetname"
  
  var
    uniqueValFlags = initOrderedTable[string, bool]()
    valOccurences = initOrderedTable[string, int]()
    uniqueVals: seq[string] = @[]
    nonuniqueVals: seq[string] = @[]
    hasAnElementKey = false
  for e in eb.elements.mvalues():
    if e.keyVals.hasKey(key):
      var val = e.getVals(key)
      if valOccurences.hasKey(val):
        valOccurences[val].inc()
        if uniqueValFlags.hasKey(val):
          uniqueValFlags.del(val)
        else:
          nonuniqueVals.add(val)
      else:
        valOccurences[val] = 1
        uniqueValFlags[val] = true

  for key in uniqueValFlags.keys():
    uniqueVals.add(key)
  return (valOccurences, uniqueVals, nonuniqueVals)

proc printTree*(eb: ElementBevy, elem: Element, indent: string, ): string =
  result = fmt("{indent}{elem.name} ({elem.id})\n")
  for child in elem.childs:
    result.add(printTree(eb, eb.elements[child], indent & "  "))

proc printTree*(eb: ElementBevy, indent: string): string =
  return eb.printTree(eb.elements[eb.elementindex[0]], indent)

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

proc editKeyVals*(e: var Element, key: string, pattern: string, 
                  editvalproc: proc(val, pattern: string): string) =
  if not e.keyVals.hasKey(key):
    raise newException(KeyNotInElementKeyVals, fmt("key {key} not a member element.keyVals"))
  var newvals: seq[string] = @[]
  for keyval in e.keyVals[key]:
    newvals.add(editvalproc(keyval, pattern))
  e.keyVals[key] = newvals
  
proc importCsv*(fp: string, sep: char = ',',
                idCol: int = 0, nameCol: int = -1,
                parentCol, childCol: int = -1,
                createOrigin: bool = false): ElementBevy =
  result = newElementBevy(createOrigin)
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
    if (nameCol >= 0) and (nameCol < csv.row.len()):
      name = csv.row[nameCol]
    if (parentCol >= 0) and (parentCol < csv.row.len()):
      parent = csv.row[parentCol]
    if childCol >= 0:
      childs.add(csv.row[childCol])
    var e = newElement(id, name, parent, childs)
    for i in 0..<csv.row.len():
      if i >= idxHeadername.len():
        raise newException(
          IndexDefect,
          fmt("row {rowcount} with column {i}: index out of range: headerIndex-entries: {idxheadername.len()}"))
      e.addKeyVal(idxHeadername[i], csv.row[i])
      
    result.addElement(e, false)
    rowcount.inc()
  csv.close()

proc toCsv*(eb: ElementBevy, sep: char = ',', fp: string) =
  let (_, unionkeys) = getUnionKeys(eb)
  var txt = join(unionkeys, $sep)
  txt.add("\n")
  for e in eb.elements.values():
    var csvrow: seq[string] = @[]
    for headerkey in unionkeys:
      if headerkey in e.keyVals:
        csvrow.add(e.keyVals[headerkey])
    txt.add(csvrow.join($sep))
    txt.add("\n")
  try:
    writeFile(fp, txt)
  except:
    raise newException(Exception, fmt("error writing csv-file: {getCurrentExceptionMsg()}"))
  
proc importSpreadsheet*(rec: seq[seq[string]], headerrow: int = 0,
                        idCol: int = 0, nameCol: int = -1,
                        parentCol, childCol: int = -1,
                        createOrigin: bool = false): ElementBevy =
  ## imports tabeldata e.g. from an excel file or similar
  result = newElementBevy(createOrigin)
  var
    headernameIdx = initTable[string, int]() 
    idxHeadername = initTable[int, string]()
  var i = 0
  for headername in rec[headerrow]:
    if headernameIdx.hasKey(headername):
      raise newException(NonUniqueKeyException, fmt("header-name is not unique: {headername}"))
    headernameIdx[headername] = i
    idxHeadername[i] = headername
    i.inc()

  for i in headerrow+1..<rec.len():
    let id = rec[i][idCol]
    var
      parent = ""
      name = ""
      childs: seq[string] = @[]
    if (nameCol >= 0) and (nameCol < rec[i].len()):
      name = rec[i][nameCol]
    if (parentCol >= 0) and (parentCol < rec[i].len()):
      parent = rec[i][parentCol]
    if (childCol >= 0) and (childCol < rec[i].len()):
      childs.add(rec[i][childCol])
    var e = newElement(id, name, parent, childs)
    for k in 0..<rec[i].len():
      if k >= idxHeadername.len():
        raise newException(
          IndexDefect,
          fmt("row {i} in record with column {k}: index out of range: headerIndex-entries: {idxheadername.len()}"))
      e.addKeyVal(idxHeadername[k], rec[i][k])
    result.addElement(e, false)

# proc importXlsx*(fp: string, sheetname: string, headeridx: int,
#                 idCol: int = 0, nameCol: int = -1,
#                 parentCol, childCol: int = -1,
#                 createOrigin: bool = false): ElementBevy =
#   result = newElementBevy(createOrigin)
#   var
#     headernameIdx = initTable[string, int]() 
#     idxHeadername = initTable[int, string]()
 
#   try:
#     let
#       wb = xl.load(fp)
#     var xlsheet: XlSheet
#     if sheetname == "":
#       xlsheet = wb.active()
#     else:
#       xlsheet  = wb.sheet(sheetname)
#     for rowidx in 0..<(rowCount(xlsheet.range)):
#       if rowidx < headeridx:
#         continue
#       if rowidx == headeridx:
#         for colidx in 0..<(colCount(row(xlsheet.range,rowidx))):
#           let val = xlsheet.row(rowidx).cell(colidx).value()
#           if val == "":
#             continue
#           headernameIdx[val] = colidx
#           idxHeadername[colidx] = val
#         if idCol >= idxHeadername.len():
#           raise newException(IndexDefect, "id-column-index out of range")
#         if nameCol >= idxHeadername.len():
#           raise newException(IndexDefect, "name-column-idx out of range")
#         if parentCol >= idxHeadername.len():
#           raise newException(IndexDefect, "parent-column-index of range")
#         if childCol >= idxHeadername.len():
#           raise newException(IndexDefect, "child-column-index out of range")
#         continue
#       let id = xlsheet.row(rowidx).cell(idCol).value()
#       var
#         parent = ""
#         name = ""
#         childs: seq[string] = @[]
#       if nameCol >= 0:
#         name = xlsheet.row(rowidx).cell(nameCol).value()
#       if (parentCol >= 0):
#         parent = xlsheet.row(rowidx).cell(parentCol).value()
#       if childCol >= 0:
#         childs.add(xlsheet.row(rowidx).cell(childCol).value())
#       var e = newElement(id, name, parent, childs)
#       for colidx in 0..<(colCount(row(xlsheet.range,rowidx))):
#         e.addKeyVal(idxHeadername[colidx], xlsheet.row(rowidx).cell(colidx).value())
#       result.addElement(e, false)
#   except:
#     raise newException(ExcelReadError, getCurrentExceptionMsg())

proc toSpreadsheet*(eb: ElementBevy): seq[seq[string]] =
  result = @[]
  var
    colnameIdx = initOrderedTable[string, int]()
    colidx = 0
    headerrow = initOrderedTable[string, bool]()
  for e in eb.elements.values():
    for key in e.keyVals.keys():
      if headerrow.hasKey(key):
        continue
      headerrow[key] = true
      colnameIdx[key] = colidx
      colidx.inc()

  var hr: seq[string] = @[]
  for k in headerrow.keys():
    hr.add(k)
  result.add(hr)
  for e in eb.elements.values():
    var row: seq[string] = @[]
    for i in 0..<headerrow.len:
      row.add("")
    for key, vals in e.keyVals.pairs():
      if colnameIdx.hasKey(key):
        row[colnameIdx[key]] = vals.join("\n")
      else:
        echo(fmt("wooohaaaaaa... this shoouldn't happen: found element key '{key}' which is not in colnameIdx"))
    result.add(row)
    
proc toSpreadsheet*(eb: ElementBevy, am: OrderedTable[string, tuple[attrname: string, useEbKey: bool]]): seq[seq[string]] =
  result = @[]

  var
    colnameIdx = initOrderedTable[string, int]()
    colidx = 0
    headerrow: seq[string] = @[]
  for attrnameTup in am.values():
    if not colnameIdx.hasKey(attrnameTup.attrname):
      headerrow.add(attrnameTup.attrname)
      colnameIdx[attrnameTup.attrname] = colidx
      colidx.inc()
  result.add(headerrow)
  
  for e in eb.elements.values():
    var row: seq[string] = @[]
    for k in headerrow:
      row.add("")
    if am.hasKey("EBID"):
      let attrname = am["EBID"].attrname
      row[colnameIdx[attrname]] = e.id
    if am.hasKey("EBNAME"):
      let attrname = am["EBNAME"].attrname
      row[colnameIdx[attrname]] = e.name
    if am.hasKey("EBPATH"):
      let attrname = am["EBPATH"].attrname
      row[colnameIdx[attrname]] = e.path
    if am.hasKey("EBLEVEL"):
      let attrname = am["EBLEVEL"].attrname
      row[colnameIdx[attrname]] = $e.level
    if am.hasKey("EBPARENT"):
      let attrname = am["EBPARENT"].attrname
      row[colnameIdx[attrname]] = e.parent
    if am.hasKey("EBCHILDS"):
      let attrname = am["EBCHILDS"].attrname
      row[colnameIdx[attrname]] = e.childs.join("\n")
    for key, vals in e.keyVals.pairs():
      if am.hasKey(key):
        let attrname = am[key].attrname
        var val = ""
        let tmpval = join(vals, "\"/\"")
        if am[key].useEbKey:
          val = fmt("\"{key}:\" \"{tmpval}\"")
        else:
          val = tmpval
        if row[colnameIdx[attrname]] == "":
          row[colnameIdx[attrname]] = val
        else:
          row[colnameIdx[attrname]] = fmt("{row[colnameIdx[attrname]]},\n{val}")
    result.add(row)

proc readKeyMap*(fp: string, separator: char):
               (OrderedTable[string, tuple[attrname: string, useEbKey: bool]],
                seq[string]) =
  var
    mapping = initOrderedTable[string, tuple[attrname: string, useEbKey: bool]]()
    attrs: seq[string] = @[]
  var csv: CsvParser
  csv.open(fp, separator)
  csv.readHeaderRow()
  var rowcount = 0
  while csv.readRow():
    if mapping.hasKey(csv.row[0]):
      raise newException(NonUniqueKeyException, fmt("key '{csv.row[0]}' is not unique in {fp}"))
    else:
      case csv.row.len()
      of 0:
        echo(fmt("no csv-data in row {rowcount}"))
      of 1:
        attrs.add(csv.row[0])
      of 2:
        if csv.row[1] in keyMapTrueVals:
          mapping[csv.row[0]] = (csv.row[0], false)
        attrs.add(csv.row[0])
      of 3:
        attrs.add(csv.row[0])
        var targetAtrName = csv.row[2]
        if targetAtrName == "":
            targetAtrName = csv.row[0]
        if csv.row[1] in keyMapTrueVals:
          mapping[csv.row[0]] = (targetAtrName, false)
      of 4:
        attrs.add(csv.row[0])
        var targetAtrName = csv.row[2]
        if targetAtrName == "":
            targetAtrName = csv.row[0]
        if csv.row[1] in keyMapTrueVals:
          if csv.row[3] in keyMapTrueVals:
            mapping[csv.row[0]] = (targetAtrName, true)
          else:
            mapping[csv.row[0]] = (targetAtrName, false)
      else:
        discard
    rowcount.inc()
  return (mapping, attrs)
    
when isMainModule:
  # echo "this is elements - hope i can help you..."
  # var myeb = importCsv("test.csv", ';', 0, 1, 5, -1, false)
  # echo myeb.elements.len()
  # var myrec = myeb.toSpreadsheet()
  # echo myrec.len()
  # echo myrec[0]
  # echo myrec[^1]
  # var my2eb = importSpreadsheet(myrec, 0, 0, 1, 5, -1, false)
  # echo my2eb.elements.len()
  # my2eb.toCsv(';', "elements-out.csv")
  let (mykeymap, attrs) = readKeyMap("anpassungen.csv", ';')
  echo mykeymap.len()
  for k, tup in mykeymap.pairs():
    echo k, " ", $tup
  echo attrs
