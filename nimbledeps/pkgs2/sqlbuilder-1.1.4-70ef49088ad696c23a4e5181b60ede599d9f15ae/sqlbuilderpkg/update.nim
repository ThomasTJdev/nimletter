# Copyright 2020 - Thomas T. Jarløv

when NimMajor >= 2:
  import db_connector/db_common
else:
  import std/db_common

import
  std/macros,
  std/strutils

import
  ./utils_private

from ./utils import ArgsContainer


proc updateSetFormat(v: string): string =
  ## The table columns that we want to update. Validate whether
  ## the user has provided equal sign or not.

  let
    field = v.strip()
    fieldSplit = field.split("=")

  #
  # Does the data have a `=` sign?
  #
  if fieldSplit.len() == 2:
    #
    # If the data is only having equal but no value, insert a `?` sign.
    # Eg. `field =`
    #
    if fieldSplit[1] == "":
      return (field & " ?")

    #
    # Otherwise just add the data as is, eg. `field = value`
    # Eg. `field = value`
    #
    else:
      return (field)

  #
  # Otherwise revert to default
  # Eg. `field = ?`
  #
  else:
    return (field & " = ?")



proc updateSet(data: varargs[string]): string =
  ## Update the SET part of the query.
  ##
  ## => ["name", "age = "]
  ## => `SET name = ?, age = ?`
  ##
  for i, d in data:
    if i > 0:
      result.add(", ")
    result.add(updateSetFormat(d))
  return result


proc updateArray(arrayType: string, arrayAppend: varargs[string]): string =
  ## Format the arrayAppend part of the query.
  for i, d in arrayAppend:
    if i > 0:
      result.add(", ")
    result.add(d & " = " & arrayType & "(" & d & ", ?)")
  return result


proc sqlUpdate*(table: string, data: varargs[string], where: varargs[string], args: ArgsContainer.query): SqlQuery =
  ## SQL builder for UPDATE queries
  ## Checks for NULL values

  var fields = "UPDATE " & table & " SET "
  for i, d in data:
    if i > 0:
      fields.add(", ")
    if args[i].isNull:
      fields.add(d & " = NULL")
    elif d.len() > 5 and d[(d.high-3)..d.high] == "NULL":
      fields.add(d)
    elif d[d.high-1..d.high] == "=":
      fields.add(d & " ?")
    else:
      fields.add(d & " = ?")

  var wes = " WHERE "
  for i, d in where:
    if i > 0:
      wes.add(" AND ")
    if d[d.high..d.high] == "=":
      wes.add(d & " ?")
    else:
      wes.add(d & " = ?")

  result = sql(fields & wes)


proc sqlUpdate*(
    table: string,
    data: varargs[string],
    where: varargs[string],
  ): SqlQuery =
  ## SQL builder for UPDATE queries
  ##
  ## Can utilize custom equal signs and can also check for NULL values
  ##
  ## data => ["name", "age = ", "email = NULL"]
  ## where => ["id = ", "name IS NULL"]
  var fields: string
  fields.add(updateSet(data))
  fields.add(sqlWhere(where))
  result = sql("UPDATE " & table & " SET " & fields)


proc sqlUpdateArrayRemove*(
    table: string,
    arrayRemove: varargs[string],
    where: varargs[string],
  ): SqlQuery =
  ## ARRAY_REMOVE
  var fields: string
  fields.add(updateArray("ARRAY_REMOVE", arrayRemove))
  fields.add(sqlWhere(where))
  result = sql("UPDATE " & table & " SET " & fields)


proc sqlUpdateArrayAppend*(
    table: string,
    arrayAppend: varargs[string],
    where: varargs[string],
  ): SqlQuery =
  ## ARRAY_APPEND
  var fields: string
  fields.add(updateArray("ARRAY_APPEND", arrayAppend))
  fields.add(sqlWhere(where))
  result = sql("UPDATE " & table & " SET " & fields)



#
#
# Macro based
#
#
proc updateSet(data: NimNode): string =
  ## Update the SET part of the query.
  ##
  ## => ["name", "age = "]
  ## => `SET name = ?, age = ?`
  ##
  for i, v in data:
    # Convert NimNode to string
    let d = $v
    if i > 0:
      result.add(", ")
    result.add(updateSetFormat(d))
  return result


macro sqlUpdateMacro*(
    table: string,
    data: varargs[string],
    where: varargs[string]
  ): SqlQuery =
  ## SQL builder for UPDATE queries
  ##
  ## Can utilize custom equal signs and can also check for NULL values
  ##
  ## data => ["name", "age = ", "email = NULL"]
  ## where => ["id = ", "name IS NULL"]
  var fields: string
  fields.add(updateSet(data))
  fields.add(sqlWhere(where))
  result = parseStmt("sql(\"" & "UPDATE " & $table & " SET " & fields & "\")")


#
# Macro arrays
#
proc updateArray(arrayType: string, arrayAppend: NimNode): string =
  # Format the arrayAppend part of the query.

  for i, v in arrayAppend:
    let d = $v
    if d == "":
      continue

    if i > 0:
      result.add(", ")

    result.add(d & " = " & $arrayType & "(" & d & ", ?)")

  return result


macro sqlUpdateMacroArrayRemove*(
    table: string,
    arrayRemove: varargs[string],
    where: varargs[string],
  ): SqlQuery =
  ## ARRAY_REMOVE macro
  var fields: string
  fields.add(updateArray("ARRAY_REMOVE", arrayRemove))
  fields.add(sqlWhere(where))
  result = parseStmt("sql(\"" & "UPDATE " & $table & " SET " & fields & "\")")


macro sqlUpdateMacroArrayAppend*(
    table: string,
    arrayAppend: varargs[string],
    where: varargs[string],
  ): SqlQuery =
  ## ARRAY_APPEND macro
  var fields: string
  fields.add(updateArray("ARRAY_APPEND", arrayAppend))
  fields.add(sqlWhere(where))
  result = parseStmt("sql(\"" & "UPDATE " & $table & " SET " & fields & "\")")
