# Copyright 2020 - Thomas T. Jarløv

when NimMajor >= 2:
  import db_connector/db_common
else:
  import std/db_common

import
  std/macros,
  std/strutils

import
  ./utils

import
  ./select




proc sqlSelect*(
    table: string,
    data: varargs[string],
    left: varargs[string],
    whereC: varargs[string],
    access: string,
    accessC: string,
    user: string,
    args: ArgsContainer.query = @[],
    useDeleteMarker: bool = true,
    tablesWithDeleteMarker: varargs[string] = (when declared(tablesWithDeleteMarkerInit): tablesWithDeleteMarkerInit else: []), #@[],
    deleteMarker = ".is_deleted IS NULL",
  ): SqlQuery {.deprecated.} =
  ##
  ## This is a legacy converter for the old sqlSelect() use.
  ##


  var leftcon: seq[tuple[table: string, tableAs: string, on: seq[string]]]
  var joinoverride: string
  for raw in left:
    if raw.len() == 0:
      continue

    if raw.len() >= 7 and raw[0..6].toLowerAscii() == "lateral":
      joinoverride = "LEFT JOIN " & raw
      continue

    let d = raw.toLowerAscii()

    let
      lsplit1 = d.split(" on ")
      lsplit2 = lsplit1[0].split(" as ")
      hasAlias = (lsplit2.len() > 1)

    leftcon.add(
      (
        table: lsplit2[0].strip(),
        tableAs: (if hasAlias: lsplit2[1].strip() else: ""),
        on: @[lsplit1[1].strip()]
      )
    )

  let
    tableSplit = table.split(" as ")
    tableName =
        if tableSplit.len() > 1:
          tableSplit[0]
        else:
          table
    tableAsName =
        if tableSplit.len() > 1:
          tableSplit[1]
        else:
          ""



  return sqlSelect(
    table     = tableName,
    tableAs   = tableAsName,
    select    = data,
    joinargs  = leftcon,
    jointype  = LEFT,
    joinoverride = joinoverride,
    where     = whereC,
    whereInField = accessC,
    whereInValue = @[access],
    customSQL = user,
    checkedArgs = args,
    useDeleteMarker = useDeleteMarker,
    tablesWithDeleteMarker = tablesWithDeleteMarker,
    deleteMarker = deleteMarker
  )


#[
##
## Raw legacy procedure
##
proc sqlSelect*(table: string, data: varargs[string], left: varargs[string], whereC: varargs[string], access: string, accessC: string, user: string): SqlQuery =
  ## SQL builder for SELECT queries
  ## Does NOT check for NULL values

  var res = "SELECT "
  for i, d in data:
    if i > 0: res.add(", ")
    res.add(d)

  var lef = ""
  for i, d in left:
    if d != "":
      lef.add(" LEFT JOIN ")
      lef.add(d)

  var wes = ""
  for i, d in whereC:
    if d != "" and i == 0:
      wes.add(" WHERE ")
    if i > 0:
      wes.add(" AND ")
    if d != "":
      wes.add(d & " ?")

  var acc = ""
  if access != "":
    if wes.len == 0:
      acc.add(" WHERE " & accessC & " in ")
      acc.add("(")
    else:
      acc.add(" AND " & accessC & " in (")
    var inVal: string
    for a in split(access, ","):
      if a == "": continue
      if inVal != "":
        inVal.add(",")
      inVal.add(a)
    acc.add(if inVal == "": "0" else: inVal)
    acc.add(")")

  when defined(testSqlquery):
    echo res & " FROM " & table & lef & wes & acc & " " & user

  when defined(test):
    testout = res & " FROM " & table & lef & wes & acc & " " & user

  result = sql(res & " FROM " & table & lef & wes & acc & " " & user)


proc sqlSelect*(table: string, data: varargs[string], left: varargs[string], whereC: varargs[string], access: string, accessC: string, user: string, args: ArgsContainer.query): SqlQuery =
  ## SQL builder for SELECT queries
  ## Checks for NULL values

  var res = "SELECT "
  for i, d in data:
    if i > 0: res.add(", ")
    res.add(d)

  var lef = ""
  for i, d in left:
    if d != "":
      lef.add(" LEFT JOIN ")
      lef.add(d)

  var wes = ""
  for i, d in whereC:
    if d != "" and i == 0:
      wes.add(" WHERE ")
    if i > 0:
      wes.add(" AND ")
    if d != "":
      if args[i].isNull:
        wes.add(d & " = NULL")
      else:
        wes.add(d & " ?")

  var acc = ""
  if access != "":
    if wes.len == 0:
      acc.add(" WHERE " & accessC & " in ")
      acc.add("(")
    else:
      acc.add(" AND " & accessC & " in (")

    var inVal: string
    for a in split(access, ","):
      if a == "": continue
      if inVal != "":
        inVal.add(",")
      inVal.add(a)
    acc.add(if inVal == "": "0" else: inVal)
    acc.add(")")

  when defined(testSqlquery):
    echo res & " FROM " & table & lef & wes & acc & " " & user

  when defined(test):
    testout = res & " FROM " & table & lef & wes & acc & " " & user

  result = sql(res & " FROM " & table & lef & wes & acc & " " & user)
]#

macro sqlSelectMacro*(
    table: string,
    data: varargs[string],
    left: varargs[string],
    whereC: varargs[string],
    access: string,
    accessC: string,
    user: string
  ): SqlQuery {.deprecated.} =
  ## SQL builder for SELECT queries
  ## Does NOT check for NULL values

  var res: string
  for i, d in data:
    if i > 0:
      res.add(", ")
    res.add($d)

  var lef: string
  for i, d in left:
    if $d != "":
      lef.add(" LEFT JOIN " & $d)

  var wes: string
  for i, d in whereC:
    if $d != "" and i == 0:
      wes.add(" WHERE ")
    if i > 0:
      wes.add(" AND ")
    if $d != "":
      wes.add($d & " ?")

  var acc: string
  if access.len() != 0:
    if wes.len == 0:
      acc.add(" WHERE " & $accessC & " in (")
    else:
      acc.add(" AND " & $accessC & " in (")
    for a in split($access, ","):
      acc.add(a & ",")
    acc = acc[0 .. ^2]
    if acc.len() == 0:
      acc.add("0")
    acc.add(")")

  when defined(testSqlquery):
    echo "SELECT " & res & " FROM " & $table & lef & wes & acc & " " & $user

  result = parseStmt("sql(\"SELECT " & res & " FROM " & $table & lef & wes & acc & " " & $user & "\")")

