
import
  sqlbuilder


import
  ../database/database_connection


proc getPageName*(): string =
  pg.withConnection conn:
    result = getValue(conn, sqlSelect(
      table = "settings",
      select = ["page_name"],
      where = ["id = 1"]
    ))
