import std/[unicode,strformat,strutils]

## module to parse and serialize texts, lines and strings by the
## `WSV-Specification <https://dev.stenway.com/WSV/Specification.html>`_

const
  whitespaceInts: seq[int32] = @[
    0x0009, #	Character Tabulation
    0x000A, #	Line Feed
    0x000B, #	Line Tabulation
    0x000C, #	Form Feed
    0x000D, #	Carriage Return
    0x0020, #	Space
    0x0085, #	Next Line
    0x00A0, #	No-Break Space
    0x1680, #	Ogham Space Mark
    0x2000, #	En Quad
    0x2001, #	Em Quad
    0x2002, #	En Space
    0x2003, #	Em Space
    0x2004, #	Three-Per-Em Space
    0x2005, #	Four-Per-Em Space
    0x2006, #	Six-Per-Em Space
    0x2007, #	Figure Space
    0x2008, #	Punctuation Space
    0x2009, #	Thin Space
    0x200A, #	Hair Space
    0x2028, #	Line Separator
    0x2029, #	Paragraph Separator
    0x202F, #	Narrow No-Break Space
    0x205F, #	Medium Mathematical Space
    0x3000 #	Ideographic Space
  ]
  dblQuote: Rune = cast[Rune](0x0022)
  slash: Rune = cast[Rune](0x002F)
  hashsign: Rune = cast[Rune](0x0023)
  newline: Rune = cast[Rune](0x000A)
  hyphenminus: Rune = cast[Rune](0x002D)

  wsvnewline: string = "\"/\""
  wsvDblQuote: string = "\"\""
  wsvHyphenMinus: string = "\"-\""
  wsvNull: string = "--NULL--"
    
type
  WsvString* = distinct string
    ## string value which follows the wsv value-specification
    ## e.g. contains no "\\n", etc.
  
  WsvEncoding* = enum
    ## to sepcify the wsv-document encoding; currently only UTF-8 is supported!
    weUtf8, weUtf16

  WsvLine* = ref object
    values*: seq[WsvString]
    whitespaces*: seq[int32]
    comment*: string
    
  WsvDocument* = ref object
    lines*: seq[WsvLine]
    encoding*: WsvEncoding

  WsvRow* = ref object
    ## like `WsvLine <#WsvLine>`_ but hold the data in values in 'real-string' way
    values*: seq[string]
    whitespaces*: seq[int32]
    comment*: string
  WsvTable* = ref object
    rows*: seq[WsvRow]
    ## To hold Data in 'real-string' way

proc newWsvDocument*(lines: seq[WsvLine] = @[], encoding: WsvEncoding = weUtf8): WsvDocument
proc newWsvLine*(line: string = ""): WsvLine

proc parseWsvFile*(fp: string): WsvDocument
  ## parses a wsv-format file-content. Calls `parseWsvText proc <#parseWsvText,string>`_
proc parseWsvText*(txt: string): WsvDocument
  ## parses wsv-formated text
proc parseWsvContent*(txt: string): WsvTable
  ## parses wsv-formated text and creates `WsvTable <#WsvTable`_ of it
proc parseWsvLine*(line: string): WsvLine
  ## parses a line which consist of WsvString's
  ##
  ## to parse a "string-line" to a WsvLine use `parseLine proc <#parseLine,string>`_
proc parseLine*(line: string): WsvLine
  ## deprecated: there's no use-case for such a function. Why?
  ##
  ## - if i have already a wsc-document i parse this by `praseWsvLine proc <#parseWsvLine,string>`_
  ## - if i would make any data to become wsv-data the convertion is not by line
  ##   but by "string-values". Therefore we have `toWsvString proc <#toWsvString,string>`_
proc serializeWsvDoc*(wsvdoc: WsvDocument, fp: string, separator: char = '\t'): string
proc toTab*(wsvdoc: WsvDocument): seq[seq[string]] # normal string, not wsv-string
proc toSeq*(wsvline: WsvLine): seq[string] # normal string, not wsv-string
proc toString*(wsvline: WsvLine, separator: string = "\t"): string # normal string, not wsv-string
proc toString*(wsvstring: WsvString): string
  ## creates a *real* string out of `WsvString <#WsvString>`_
  ##
  ## it is **not** the same as `$ proc <#$,WsvString>`_
  ## look there for an example
proc toString*(s: string): string
  ## value is in "real-string-format" but has WsvString-content.

proc toWsvString*(s: string): WsvString
  ## make a string become a `WsvString <#WsvString>`_
proc toWsvSeq*(list: seq[string]): seq[WsvString]
proc toWsvTab*(tab: seq[seq[string]]): seq[seq[WsvString]]
proc toWsvLine*(list: seq[string]): WsvLine
proc toWsvDoc*(tab: seq[seq[string]]): WsvDocument

proc add*(wsvstring: var WsvString, s: string)
proc len*(wsvstring: WsvString): int

proc `==`*(wsvstring1, wsvstring2: WsvString): bool
func `$`*(wsvstring: WsvString): string
  ## creates a 'string'-representation from the `WsvString <#WsvString>`_
  ##
  ## this is **not** the same as `toString proc <#toString,WsvString>`_
  ##
  ## ***example:***
  ##
  ##  let wsvstring: WsvString = %"foo ""bar"""
  ##
  ##  assert $wsvstring == "\"foo \"\"bar\"\"\""
  ##
  ##  assert wsvstring.toString() == "foo \"bar\""
func `%`*(s: string): WsvString

proc hasOneOf(s: string, collection: seq[int32]): bool
func isWhitespaceChar(c: int32): bool
func isWhitespaceString(s: string): bool
func isDblQuote(r: Rune): bool
func isNextRuneDblQuote(runes: seq[Rune], curIndex: int): bool
func isNewlineEscapeSequence(runes: seq[Rune], curIndex: int): bool

proc newWsvDocument*(lines: seq[WsvLine] = @[], encoding: WsvEncoding = weUtf8): WsvDocument =
  return WsvDocument(lines: lines, encoding: encoding)

proc newWsvLine*(line: string = ""): WsvLine =
  discard

proc parseWsvFile*(fp: string): WsvDocument =
  try:
    result = parseWsvText(readFile(fp))
  except:
    echo getCurrentExceptionMsg()

proc parseWsvText*(txt: string): WsvDocument =
  result = newWsvDocument()
  let lines = split(txt, "\n")
  var linecounter = 0
  for line in lines:
    if len(line) == 0:
      continue
    if line[0] == '#':
      var wl = WsvLine(comment: line)
      result.lines.add(wl)
    else:
      var wsvline = parseWsvLine(line)
      result.lines.add(wsvline)
    inc(linecounter)

proc parseWsvContent*(txt: string): WsvTable =
  discard
    
proc parseLine*(line: string): WsvLine =
  discard
#   result = WsvLine()
#   let runes = toRunes(line)
#   var
#     currentWord = ""
#     isPendingDblQuote = false
#     lastRune: Rune

#   var i = -1
#   while i < runes.len()-1:
#     inc(i)
#     let r = runes[i]
#     if isWhitespaceChar(int32(r)):
#       if isPendingDblQuote:
#         currentWord.add($r)
#       else:
#         if currentWord.len() > 0:
#           result.values.add(%currentWord)
#           currentWord = ""
#     elif r == hashsign:
#       if isPendingDblQuote:
#         currentWord.add($r)
#       else:
#         if currentWord.len() > 0:
#           result.values.add(%currentWord)
#           currentWord = ""
#         result.comment = $runes[i..^1]
#         break
#     else:
#       if r.isDblQuote:
#         if isPendingDblQuote:
#           if isNextRuneDblQuote(runes, i):
#             currentWord.add($r)
#             inc(i)
#           elif isNewlineEscapeSequence(runes, i):
#             currentWord.add("\n")
#             i = i+2
#           else:
#             isPendingDblQuote = false
#             if currentWord.len() > 0:
#               result.values.add(%currentWord)
#               currentWord = ""
#         else:
#           isPendingDblQuote = true
#       else:
#         currentWord.add($r)
#     lastRune = r

#   if currentWord.len() > 0:
#     result.values.add(%currentWord)

proc parseWsvLine*(line: string): WsvLine =
  result = WsvLine()
  let runes = toRunes(line)
  var
    currentWord: WsvString = %""
    isPendingDblQuote = false
    lastRune: Rune

  var i = -1
  while i < runes.len()-1:
    inc(i)
    let r = runes[i]
    if isWhitespaceChar(int32(r)):
      if isPendingDblQuote:
        currentWord.add($r)
      else:
        if currentWord.len() > 0:
          result.values.add(currentWord)
          currentWord = %""
    elif r == hashsign:
      if isPendingDblQuote:
        currentWord.add($r)
      else:
        if currentWord.len() > 0:
          result.values.add(currentWord)
          currentWord = %""
        result.comment = $runes[i..^1]
        break
    elif r == hyphenminus:
      if isPendingDblQuote:
        currentWord.add($r)
      else:
        if currentWord.len() > 0:
          currentWord.add($r)
        else:
          if int32(runes[i+1]) in whitespaceInts:
            result.values.add(%wsvNull)
          else:
            currentWord.add($r)
    else:
      if r.isDblQuote:
        if isPendingDblQuote:
          if isNextRuneDblQuote(runes, i):
            currentWord.add(wsvDblQuote)
            inc(i)
          elif isNewlineEscapeSequence(runes, i):
            currentWord.add(wsvnewline)
            i = i+2
          else:
            isPendingDblQuote = false
            currentWord.add($r)
            if currentWord.len() > 0:
              result.values.add(currentWord)
              currentWord = %""
        else:
          isPendingDblQuote = true
          currentWord.add($r)
      else:
        currentWord.add($r)
    lastRune = r

  if currentWord.len() > 0:
    result.values.add(currentWord)
    
proc serializeWsvDoc*(wsvdoc: WsvDocument, fp: string, separator: char = '\t'): string =
  if not int32(separator).isWhitespaceChar:
    echo "invalid whitespace-char as separator"
    return "--invalid-whitespace-char--"
  for wsvline in wsvdoc.lines:
    result.add(wsvline.toString("           "))
    result.add("\n")  

proc toTab*(wsvdoc: WsvDocument): seq[seq[string]] =
  result = @[]
  for wsvline in wsvdoc.lines:
    result.add(@[wsvline.toSeq()])

proc toSeq*(wsvline: WsvLine): seq[string] =
  result = @[]
  for val in wsvline.values:
    result.add(val.toString())
  result.add(wsvline.comment)

proc toString*(wsvline: WsvLine, separator: string = "\t"): string =
  if separator.isWhitespaceString():
    result = join(wsvLine.toSeq(), separator)
  else:
    echo "invalid whitespace-char as separator"
    return "--invalid-whitespace-char--"

proc toString*(wsvstring: WsvString): string =
  return ($wsvstring.toString)
  # if result == "":
  #     return "NIL"
  # if result == wsvDblQuote:
  #     return ""
  # if result == wsvHyphenMinus:
  #   return "-"
  # var expectSurroundingDblQuotes = false
  # if result.contains(wsvDblQuote):
  #   expectSurroundingDblQuotes = true
  #   result = result.replace(wsvDblQuote, "\"")
  # if result.contains($hashsign):
  #   expectSurroundingDblQuotes = true
  # if result.hasOneOf(whitespaceInts):
  #   expectSurroundingDblQuotes = true
  # if expectSurroundingDblQuotes:
  #   if (result[0] != '"') or (result[^1] != '"'):
  #     echo "malformed wsv-string, bye..."
  #     system.quit()
  #   result = result[1..^2]
  # result = result.replace(wsvnewline, "\n")

proc toString*(s: string): string =
  result = s
  if result == "":
      return "NIL"
  if result == wsvDblQuote:
      return ""
  if result == wsvHyphenMinus:
    return "-"
  var expectSurroundingDblQuotes = false
  if result.contains(wsvDblQuote):
    expectSurroundingDblQuotes = true
    result = result.replace(wsvDblQuote, "\"")
  if result.contains($hashsign):
    expectSurroundingDblQuotes = true
  if result.hasOneOf(whitespaceInts):
    expectSurroundingDblQuotes = true
  if expectSurroundingDblQuotes:
    if (result[0] != '"') or (result[^1] != '"'):
      echo "malformed wsv-string, bye..."
      system.quit()
    result = result[1..^2]
  result = result.replace(wsvnewline, "\n")
  
proc toWsvString*(s: string): WsvString =
  if s == "":
    return %wsvDblQuote
  if s == "-":
    return %wsvHyphenMinus
  var wsvstring: WsvString = %""
  let runes = toRunes(s)
  var needSurroundingDblQuotes = false
  for rune in runes:
    var value = $rune
    if rune == dblQuote:
      needSurroundingDblQuotes = true
      value = "\"\""
    elif int32(rune) in whitespaceInts: # \n an CR is in Whitspacelist
      needSurroundingDblQuotes = true
    if rune == newline:
      needSurroundingDblQuotes = true
      value = "\"/\""
    wsvstring.add(value)
  if needSurroundingDblQuotes:
    wsvstring.add("\"")
    wsvstring = %fmt("\"{wsvstring}")

  return wsvstring

proc toWsvSeq*(list: seq[string]): seq[WsvString] =
  result = @[]
  for s in list:
    result.add(s.toWsvString())

proc toWsvTab*(tab: seq[seq[string]]): seq[seq[WsvString]] =
  result = @[]
  for list in tab:
    result.add(list.toWsvSeq)

proc toWsvLine*(list: seq[string]): WsvLine =
  result = WsvLine(whitespaces: @[])
  result.values = list.toWsvSeq()

proc toWsvDoc*(tab: seq[seq[string]]): WsvDocument =
  result = WsvDocument(encoding: weUtf8)
  for list in tab:
    result.lines.add(list.toWsvLine())
    
func isNextRuneDblQuote(runes: seq[Rune], curIndex: int): bool =
  if curIndex+1 >= len(runes):
    return false
  if runes[curIndex+1] == dblQuote:
    return true
  else:
    return false

func isNewlineEscapeSequence(runes: seq[Rune], curIndex: int): bool =
  if curIndex+2 >= len(runes):
    return false
  if (runes[curIndex+1] == slash) and (runes[curIndex+2] == dblQuote):
    return true
  else:
    return false

func isWhitespaceChar(c: int32): bool =
  if c in whitespaceInts:
    return true
  else:
    return false

func isWhitespaceString(s: string): bool =
  for c in s:
    if not int32(c).isWhitespaceChar():
      return false
  return true
  
func isDblQuote(r: Rune): bool =
  if r == dblQuote:
    return true
  else:
    return false

proc len*(wsvstring: WsvString): int =
  return string(wsvstring).len()
    
proc add*(wsvstring: var WsvString, s: string) =
  string(wsvstring).add(s)

proc `==`*(wsvstring1, wsvstring2: WsvString): bool =
  if string(wsvstring1) == string(wsvstring2):
    return true
  else:
    return false
    
func `$`*(wsvstring: WsvString): string =
  return string(wsvstring)
    
func `%`*(s: string): WsvString =
  return WsvString(s)

proc hasOneOf(s: string, collection: seq[int32]): bool =
  for val in collection:
    if s.contains($(cast[Rune](val))):
      return true
  return false
  
when isMainModule:
  # let wsvs = toWsvString(test)
  # let s = wsvs.toString()
  # echo wsvs
  # if s == test:
  #   echo "passt"
  # else:
  #   echo "passt nicht"
  #   echo test
  #   echo s

  let wsvdoc = parseWsvFile("test.wsv")
  for wl in wsvdoc.lines:
    # echo wl.values, ": ", wl.comment
    for wsvstring in wl.values:
      var s = wsvstring.toString()
      # echo wsvstring, " ::-->> ", s
      var nws = s.toWsvString()
      if wsvstring == nws:
        echo "yeah!"
      else:
        echo "oh man..."
        echo(fmt("'{wsvstring}'\n'{s}'\n'{nws}'"))
      
