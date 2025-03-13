import std/[tables]
import xl
import ./[wsv]
import ./butils/[computils]

proc xlsx2wsv*(fp, sheetname: string, columns: seq[int]): seq[seq[string]] =
  var rec: seq[seq[string]] = @[]
  try:
    let
      wb = xl.load(fp)
      xlsheet = wb.sheet(sheetname)
    for i in 0..(rowCount(xlsheet.range) - 1):
      # for k in 0..(colCount(row(xlsheet.range,i)) - 1):
      var row: seq[string] = @[]
      for k in columns:
        let val = xlsheet.row(i).cell(k).value()
        row.add($(val.toWsvString()))
      rec.add(row)
  except:
    echo $getCurrentExceptionMsg()
  return rec

when isMainModule:
  let rvw = xlsx2wsv("rvw.xlsx", "Tabelle1", @[0,4])
  let qlah = xlsx2wsv("80124-nov-release-2024.xlsx", "Tabelle1", @[0,2])

  echo "RVW : ", $rvw.len()
  echo "QLAH : ", $qlah.len()

  var
    qlahonly = initOrderedTable[string, string]() # key: ObjecId
    rvwonly = initOrderedTable[string, string]() # key: ObjecId
    intersect = initOrderedTable[string, tuple[id, text: string]]() # key: ObjecId QLAH, value: id: RVW-ID
  var foundRvwIds = initOrderedTable[string, bool]()
  for qlahrow in qlah:
    if qlahrow[1] == "":
      continue
    var foundQlahRow = false
    for rvwrow in rvw:
      if qlahrow[1] == rvwrow[1]:
        foundQlahRow = true
        foundRvwIds[rvwrow[0]] = true
        if intersect.hasKey(qlahrow[0]):
          echo "diese QLAH ID habe ich schon!"
        else:
          intersect[qlahrow[0]] = (rvwrow[0], qlahrow[1])
        break
    if foundQlahRow:
      foundQlahRow = false
    else:
      qlahonly[qlahrow[0]] = qlahrow[1]
  for rvwrow in rvw:
    if not foundRvwIds.hasKey(rvwrow[0]):
      rvwonly[rvwrow[0]] = rvwrow[1]
    
  echo "Intersect: ", $intersect.len()
  echo "QLAH only: ", $qlahonly.len()
  echo "RVW only: ", $rvwonly.len()

  var summary = "80124 Object ID\tRVW Object ID\tObject Text English\n"
  
  var workbook = newWorkbook()
  var sheet = workbook.add("diff")

  var row = 0
  for qlahid, tup in intersect.pairs():
    sheet.cell(row, 0).value = qlahid
    sheet.cell(row, 1).value = tup.id
    sheet.cell(row, 2).value = tup.text.toString()
    row.inc()
  for qlahid, qlahval in qlahonly.pairs():
    sheet.cell(row, 0).value = qlahid
    sheet.cell(row, 2).value = qlahval
    row.inc()
  for rvwid, rvwval in rvwonly.pairs():
    sheet.cell(row, 1).value = rvwid
    sheet.cell(row, 2).value = rvwval
    row.inc()
  
  workbook.save("diff.xlsx")
  

