# Copyright Thomas T. Jarløv (TTJ) - ttj@ttj.dk

when NimMajor >= 2:
  import db_connector/db_common
else:
  import std/db_common


import
  std/macros,
  std/strutils


proc querycompare*(a, b: SqlQuery): bool =
  var
    a1: seq[string]
    b1: seq[string]
  for c in splitWhitespace(string(a).toLowerAscii()):
    a1.add($c)
  for c in splitWhitespace(string(b).toLowerAscii()):
    b1.add($c)

  if a1 != b1:
    echo ""
    echo "a1: ", string(a)
    echo "b1: ", string(b).replace("\n", " ").splitWhitespace().join(" ")
    echo ""

  return a1 == b1


proc dbQuotePrivate*(s: string): string =
  ## DB quotes the string.
  result = "'"
  for c in items(s):
    case c
    of '\'': add(result, "''")
    of '\0': add(result, "\\0")
    else: add(result, c)
  add(result, '\'')



proc formatWhereParams*(v: string): string =
  ## Format the WHERE part of the query.
  let
    field = v.strip()

  var fieldSplit: seq[string]
  if field.contains(" "):
    if field.contains("="):
      fieldSplit = field.split("=")
    elif field.contains("IS NOT"):
      fieldSplit = field.split("IS NOT")
    elif field.contains("IS"):
      fieldSplit = field.split("IS")
    elif field.contains("NOT IN"):
      fieldSplit = field.split("NOT IN")
    elif field.contains("IN"):
      fieldSplit = field.split("IN")
    elif field.contains("!="):
      fieldSplit = field.split("!=")
    elif field.contains("<="):
      fieldSplit = field.split("<=")
    elif field.contains(">="):
      fieldSplit = field.split(">=")
    elif field.contains("<"):
      fieldSplit = field.split("<")
    elif field.contains(">"):
      fieldSplit = field.split(">")
  else:
    fieldSplit = field.split("=")

  #
  # Does the data have a `=` sign?
  #
  if fieldSplit.len() >= 2:
    #
    # If the data is only having equal but no value, insert a `?` sign
    #
    if fieldSplit[1] == "":
      return (field & " ?")
    #
    # Otherwise just add the data as is, eg. `field = value`
    #
    else:
      return (field)

  #
  # Otherwise revert to default
  #
  else:
    return (field & " = ?")



proc hasIllegalFormats*(query: string): string =
  const illegalFormats = [
    "WHERE AND",
    "WHERE OR",
    "AND AND",
    "OR OR",
    "AND OR",
    "OR AND",
    "WHERE IN",
    "WHERE =",
    "WHERE >",
    "WHERE <",
    "WHERE !",
    "WHERE LIKE",
    "WHERE NOT",
    "WHERE IS",
    "WHERE NULL",
    "WHERE ANY"
  ]

  for illegalFormat in illegalFormats:
    if illegalFormat in query:
      return illegalFormat


  #
  # Parentheses check
  #
  let
    parentheseOpen = count(query, "(")
    parentheseClose = count(query, ")")

  if parentheseOpen > parentheseClose:
    return "parentheses does not match. Missing closing parentheses. (" & $parentheseOpen & " open, " & $parentheseClose & " close)"
  elif parentheseOpen < parentheseClose:
    return "parentheses does not match. Missing opening parentheses. (" & $parentheseOpen & " open, " & $parentheseClose & " close)"


  #
  # Check for double insert
  #
  let noSpaces = query.strip().replace(" ", "")

  const nospaceBad = [
    "??",
    "=?,?,",
    "=?,AND",
    "=?,OR",
    "AND?,",
    "OR?,",
  ]

  for b in nospaceBad:
    if b in noSpaces:
      return "wrong position of ?. (" & b & ")"



  #
  # Bad ? substittution
  #
  const badSubstitutions = [
    "= ? AND ?",
    "= ? OR ?"
  ]
  const badSubstitutionsAccept = [
    " = ? AND ? ANY ",
    " = ? AND ? IN ",
    " = ? AND ? = "
  ]
  for o in badSubstitutions:
    if o in query:
      var pass: bool
      for b in badSubstitutionsAccept:
        if b in query:
          pass = true
          break
      if not pass:
        return "bad ? substitution. (= ? AND ?)"



proc sqlWhere*(where: varargs[string]): string =
  ## the WHERE part of the query.
  ##
  ## => ["name", "age = "]
  ## => `WHERE name = ?, age = ?`
  ##
  ## => ["name = ", "age >"]
  ## => `WHERE name = ?, age > ?`
  var wes = " WHERE "
  for i, v in where:
    if i > 0:
      wes.add(" AND ")
    wes.add(formatWhereParams(v))
  return wes

proc sqlWhere*(where: NimNode): string =
  ## the WHERE part of the query.
  ##
  ## => ["name", "age = "]
  ## => `WHERE name = ?, age = ?`
  ##
  ## => ["name = ", "age >"]
  ## => `WHERE name = ?, age > ?`
  var wes = " WHERE "
  for i, v in where:
    # Convert NimNode to string
    let d = $v
    if i > 0:
      wes.add(" AND ")
    wes.add(formatWhereParams(d))
  return wes