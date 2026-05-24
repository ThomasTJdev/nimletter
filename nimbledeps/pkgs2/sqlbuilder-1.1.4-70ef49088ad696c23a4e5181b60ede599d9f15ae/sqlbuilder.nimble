# Package

version       = "1.1.4"
author        = "ThomasTJdev"
description   = "SQL builder"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 0.20.2"
when NimMajor >= 2:
  requires "db_connector >= 0.1.0"





proc runLegacy() =
  exec "nim c -d:dev -r tests/legacy_convert/test_legacy.nim"
  exec "nim c -d:dev -r tests/legacy_convert/test_legacy_with_softdelete.nim"
  exec "nim c -d:dev -r tests/legacy_convert/test_legacy_with_softdelete2.nim"

task testlegacy, "Test legacy":
  runLegacy()


proc runSelect() =
  exec "nim c -d:dev -r tests/select/test_select.nim"
  exec "nim c -d:dev -r tests/select/test_select_arrays.nim"
  exec "nim c -d:dev -r tests/select/test_select_is.nim"
  exec "nim c -d:dev -r tests/select/test_select_deletemarker.nim"
  exec "nim c -d:dev -r tests/select/test_select_const.nim"
  exec "nim c -d:dev -r tests/select/test_select_const_deletemarker.nim"
  exec "nim c -d:dev -r tests/select/test_select_const_where.nim"

task testselect, "Test select statement":
  runSelect()


proc runInsert() =
  exec "nim c -d:dev -r tests/insert/test_insert_db.nim"
  exec "nim c -d:dev -r tests/insert/test_insert.nim"

task testinsert, "Test insert statement":
  runInsert()


proc runUpdate() =
  exec "nim c -d:dev -r tests/update/test_update.nim"
  exec "nim c -d:dev -r tests/update/test_update_arrays.nim"

task testupdate, "Test update statement":
  runUpdate()


proc runDelete() =
  exec "nim c -d:dev -r tests/delete/test_delete.nim"

task testdelete, "Test delete statement":
  runDelete()


proc runQueryCalls() =
  exec "nim c -d:dev -r tests/query_calls/test_query_calls.nim"

task testquerycalls, "Test query calls":
  runQueryCalls()


proc runToTypes() =
  exec "nim c -d:dev -r tests/totypes/test_result_to_types.nim"

task testresulttotypes, "Test result to types":
  runToTypes()


proc runArgs() =
  exec "nim c -d:dev -r tests/custom_args/test_args.nim"

task testargs, "Test args":
  runArgs()


proc runImport() =
  exec "nim c -d:dev -r tests/importpackage/test_import1.nim"
  exec "nim c -d:dev -r tests/importpackage/test_import2.nim"

task testimport, "Test import":
  runImport()


task test, "Test":
  runLegacy()
  runSelect()
  runInsert()
  runUpdate()
  runDelete()
  runQueryCalls()
  runToTypes()
  runArgs()
  runImport()