import xl
import ./[wsv]

proc xlsx2wsv*(fp, sheetname: string, columns: seq[int]) =
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
        row.add((val.toWsvString()).toString)
      rec.add(row)
  except:
    echo $getCurrentExceptionMsg()
  echo rec[100][0]
  echo rec[100][1]

when isMainModule:
  xlsx2wsv("rvw.xlsx", "Tabelle1", @[0,4])
