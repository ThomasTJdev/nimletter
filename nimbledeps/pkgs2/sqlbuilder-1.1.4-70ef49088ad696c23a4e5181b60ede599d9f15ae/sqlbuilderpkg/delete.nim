# Copyright 2020 - Thomas T. Jarløv

when NimMajor >= 2:
  import db_connector/db_common
else:
  import std/db_common

import
  std/macros

import
  ./utils_private

from ./utils import ArgsContainer


proc sqlDelete*(table: string, where: varargs[string]): SqlQuery =
  ## SQL builder for DELETE queries
  ## Does NOT check for NULL values

  var res = "DELETE FROM " & table
  if where.len > 0:
    res.add sqlWhere(where)
  result = sql(res)


proc sqlDelete*(table: string, where: varargs[string], args: ArgsContainer.query): SqlQuery =
  ## SQL builder for DELETE queries
  ## Checks for NULL values

  var res = "DELETE FROM " & table
  if where.len > 0:
    res.add(sqlWhere(where))
  result = sql(res)


macro sqlDeleteMacro*(table: string, where: varargs[string]): SqlQuery =
  ## SQL builder for SELECT queries
  ## Does NOT check for NULL values

  var res = "DELETE FROM " & $table
  if where.len > 0:
    res.add sqlWhere(where)
  result = parseStmt("sql(\"" & res & "\")")
