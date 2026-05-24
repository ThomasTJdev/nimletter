# Copyright Thomas T. Jarløv (TTJ) - ttj@ttj.dk

import
  std/strutils


# proc toSnakeCase(s: string): string =
#   for c in s:
#     if c.isUpperAscii():
#       if len(result) > 0:
#         result.add('_')
#       result.add(c.toLowerAscii())
#     else:
#       result.add(c)

proc parseVal[T: bool](data: string, v: var T) =
  v = (data == "t" or data == "true")

proc parseFloat[T: float](data: string, v: var T) =
  if data == "":
    v = 0.0
  else:
    v = data.parseFloat()

proc parseVal[T: int](data: string, v: var T) =
  if data == "":
    v = 0
  else:
    v = data.parseInt()

proc parseVal[T: string](data: string, v: var T) =
  v = data


proc parseVal[T: bool](v: var T) = (v = false)

proc parseVal[T: float](v: var T) = (v = 0.0)

proc parseVal[T: int](v: var T) = (v = 0)

proc parseVal[T: string](v: var T) = (v = "")


proc sqlToType*[T](t: typedesc[T], columns, val: seq[string]): T =
  let tmp = t()

  for fieldName, field in tmp[].fieldPairs:
    var
      found = false
    for ci in 0..columns.high:
      if columns[ci] == fieldName:#.toSnakeCase:
        parseVal(val[ci], field)
        found = true
        break
    if not found:
      parseVal(field)
    else:
      found = false

  return tmp


proc sqlToType*[T](t: typedesc[T], columns: seq[string], vals: seq[seq[string]]): seq[T] =
  for v in vals:
    result.add(sqlToType(t, columns, v))
  return result


proc sqlToTypeAs*[T](t: typedesc[T], columns, val: seq[string]): T =
  let tmp = t()

  for fieldName, field in tmp[].fieldPairs:
    var
      found = false
    for ci in 0..columns.high:
      let cSplit = if columns[ci].contains(" as "): columns[ci].split(" as ") else: columns[ci].split(" AS ")
      if cSplit.len() == 2:
        if cSplit[1].strip() == fieldName:
          parseVal(val[ci], field)
          found = true
          break
    if not found:
      parseVal(field)
    else:
      found = false

  return tmp
