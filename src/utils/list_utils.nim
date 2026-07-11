


import
  std/[
    algorithm,
    json,
    sequtils,
    strutils,
    tables,
    times
  ]


import
  sqlbuilder


import
  ../database/database_connection,
  ../scheduling/schedule_mail


proc listIDfromIdentifier*(listIdentifer: string): string =
  if listIdentifer == "":
    return ""

  pg.withConnection conn:
    result = getValue(conn, sqlSelect(
        table = "lists",
        select = ["id"],
        where = ["identifier = ?", "is_deleted IS NULL"]
      ), listIdentifer)


proc isListDeleted*(listID: string): bool =
  ## A list is soft-deleted via lists.is_deleted (never hard-deleted). Callers
  ## on the subscribe/enqueue path must use this to avoid re-subscribing
  ## contacts to a "deleted" list, which would otherwise keep generating mail.
  if listID == "":
    return false

  pg.withConnection conn:
    result = getValue(conn, sqlSelect(
        table = "lists",
        select = ["id"],
        where = ["id = ?", "is_deleted IS NOT NULL"]
      ), listID).len() > 0


proc listIDsFromUUIDs*(uuids: seq[string], includeDefaultList = true): tuple[requireOptIn: bool, ids: seq[string]] =
  var
    ids: seq[string]
    requireOptIn = false

  if includeDefaultList:
    ids.add("1")

  if uuids.len == 0:
    return (requireOptIn, ids)

  pg.withConnection conn:
    let data = getAllRows(conn, sqlSelect(
        table = "lists",
        select = ["id", "require_optin"],
        where = ["uuid = ANY(?::uuid[])", "is_deleted IS NULL"]
      ), "{" & uuids.join(",") & "}")

    for row in data:
      if row[0] == "1":
        continue
      ids.add(row[0])
      if row[1] == "t" and not requireOptIn:
        requireOptIn = true

  return (requireOptIn, ids)