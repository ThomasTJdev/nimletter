# Copyright 2020 - Thomas T. Jarløv

when NimMajor >= 2:
  import db_connector/db_common
else:
  import std/db_common

import
  std/macros,
  std/strutils

from ./utils import ArgsContainer

proc sqlInsert*(table: string, data: varargs[string], args: ArgsContainer.query): SqlQuery =
  ## SQL builder for INSERT queries
  ## Checks for NULL values

  var fields = "INSERT INTO " & table & " ("
  var vals = ""
  for i, d in data:
    if args[i].isNull:
      continue
    if i > 0:
      fields.add(", ")
      vals.add(", ")
    fields.add(d)
    vals.add('?')

  result = sql(fields & ") VALUES (" & vals & ")")


proc sqlInsert*(table: string, data: varargs[string], args: seq[string] = @[]): SqlQuery =
  ## SQL builder for INSERT queries
  ##
  ## Can check for NULL values manually typed or by comparing
  ## the length of the data and args sequences.
  ##
  ## data = @["id", "name", "age"]
  ## args = @["1", "Thomas", "NULL"]
  ## => INSERT INTO table (id, name, age) VALUES (?, ?, NULL)
  ##
  ## data = @["id", "name", "age"]
  ## args = @["1", "Thomas"] or @[]
  ## => INSERT INTO table (id, name, age) VALUES (?, ?, ?)

  var
    fields = "INSERT INTO " & table & " ("
    vals = ""

  let
    checkArgs = data.len() == args.len()


  for i, d in data:
    if i > 0:
      fields.add(", ")
      vals.add(", ")

    #
    # Check for manual null and then short circuit
    #
    if d.endsWith(" = NULL"):
      fields.add(d.split(" = NULL")[0])
      vals.add("NULL")
      continue

    #
    # Insert field name
    #
    fields.add(d)

    #
    # Insert value parameter
    #
    # Check corresponding args
    if checkArgs:
      if args[i].len() == 0 or args[i] == "NULL":
        vals.add("NULL")
      else:
        vals.add('?')
    #
    # No args, just add parameter
    #
    else:
      vals.add('?')

  result = sql(fields & ") VALUES (" & vals & ")")


macro sqlInsertMacro*(table: string, data: varargs[string]): SqlQuery =
  ## SQL builder for INSERT queries
  ## Does NOT check for NULL values

  var fields = "INSERT INTO " & $table & " ("
  var vals = ""
  for i, d in data:
    if i > 0:
      fields.add(", ")
      vals.add(", ")
    if ($d).endsWith(" = NULL"):
      fields.add(($d).split(" = NULL")[0])
      vals.add("NULL")
      continue
    fields.add($d)
    vals.add('?')
  result = parseStmt("sql(\"" & $fields & ") VALUES (" & $vals & ")\")")
