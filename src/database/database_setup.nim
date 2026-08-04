
import
  std/strutils

import
  ./database_connection


# $1 rolename, $2 user, $3 password
const createUser = """
IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$1') THEN
  CREATE USER $2 WITH PASSWORD '$3';
"""

# $1 dbname, $2 user
const createDatabase = """
IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$1') THEN
  CREATE DATABASE $1 OWNER $2;
"""

# $1 dbname, $2 user
const grantPrivileges = """
GRANT ALL PRIVILEGES ON DATABASE $1 TO $2;
"""


proc readDbSchema*(): string =
  when defined(release):
    readFile("./db_schema.sql")
  else:
    readFile("./src/database/db_schema.sql")


proc databaseMigrate*() =
  ## Apply incremental schema changes from the changelog section of db_schema.sql.
  ## Safe to run on every startup — each statement uses IF NOT EXISTS.
  let changelogMarker = "-- Changelog"
  let dbSchema = readDbSchema()
  let changelogStart = dbSchema.find(changelogMarker)
  if changelogStart < 0:
    return

  let changelogSql = dbSchema[changelogStart .. ^1]
  for sqlItem in changelogSql.split(";\n"):
    let statement = sqlItem.strip()
    if statement == "" or statement == changelogMarker:
      continue
    if not statement.startsWith("ALTER TABLE") and not statement.startsWith("CREATE INDEX"):
      continue

    try:
      pg.withConnection conn:
        exec(conn, sql(statement & ";"))
    except:
      echo "Error executing migration SQL: " & statement
      echo "Got this error: " & getCurrentExceptionMsg()


proc databaseCreate*() =
  let dbSchema = readDbSchema()
  let dbSplit = dbSchema.split(";\n")

  pg.withConnection conn:
    for sqlItem in dbSplit:
      if sqlItem.strip() == "":
        continue

      try:
        echo "Executing SQL: " & sqlItem
        exec(conn, sql(sqlItem.strip() & ";"))
      except:
        echo "Error executing SQL: " & sqlItem
        echo "Got this error code: " & getCurrentExceptionMsg()

    if getAllRows(conn, sql("SELECT * FROM mails")).len > 0:
      return

    exec(conn, sql("INSERT INTO mails (name, identifier, category, send_once, contentHTML, contentEditor, subject) VALUES (?, ?, ?, ?, ?, ?, ?);"), "Double Opt-In", "double-opt-in", "template", "false", "<div style=\"background-color:#F5F5F5;color:#262626;font-family:&quot;Helvetica Neue&quot;, &quot;Arial Nova&quot;, &quot;Nimbus Sans&quot;, Arial, sans-serif;font-size:16px;font-weight:400;letter-spacing:0.15008px;line-height:1.5;margin:0;padding:32px 0;min-height:100%;width:100%\"><table align=\"center\" width=\"100%\" style=\"margin:0 auto;max-width:600px;background-color:#FFFFFF\" role=\"presentation\" cellSpacing=\"0\" cellPadding=\"0\" border=\"0\"><tbody><tr style=\"width:100%\"><td><div style=\"padding:24px 32px 24px 32px\"><h2 style=\"font-weight:bold;margin:0;font-size:24px;padding:16px 24px 16px 24px\">Hi {{ firstname | there }}</h2><div style=\"font-weight:normal;padding:16px 24px 16px 24px\">We're glad to have you with us at {{ pagename }}!</div><div style=\"font-weight:normal;padding:16px 24px 16px 24px\">To finish subscribing to our emails, just click the button below. You can unsubscribe anytime if you change your mind.</div><div style=\"text-align:center;padding:16px 24px 16px 24px\"><a href=\"{{ hostname }}/subscribe/optin?contactUUID={{ contactUUID }}\" style=\"color:#FFFFFF;font-size:16px;font-weight:bold;background-color:#4F46E5;border-radius:4px;display:block;padding:12px 20px;text-decoration:none\" target=\"_blank\"><span><!--[if mso]><i style=\"letter-spacing: 20px;mso-font-width:-100%;mso-text-raise:30\" hidden>&nbsp;</i><![endif]--></span><span>Subscribe!</span><span><!--[if mso]><i style=\"letter-spacing: 20px;mso-font-width:-100%\" hidden>&nbsp;</i><![endif]--></span></a></div></div></td></tr></tbody></table></div>", "{ \"root\": { \"type\": \"EmailLayout\", \"data\": { \"backdropColor\": \"#F5F5F5\", \"canvasColor\": \"#FFFFFF\", \"textColor\": \"#262626\", \"fontFamily\": \"MODERN_SANS\", \"childrenIds\": [ \"block-1737229372503\" ] } }, \"block-1737229372503\": { \"type\": \"Container\", \"data\": { \"style\": { \"padding\": { \"top\": 24, \"bottom\": 24, \"right\": 32, \"left\": 32 } }, \"props\": { \"childrenIds\": [ \"block-1737229386674\", \"block-1737229395871\", \"block-1737229536738\", \"block-1737229551815\" ] } } }, \"block-1737229386674\": { \"type\": \"Heading\", \"data\": { \"props\": { \"text\": \"Hi {{ firstname | there }}\" }, \"style\": { \"padding\": { \"top\": 16, \"bottom\": 16, \"right\": 24, \"left\": 24 } } } }, \"block-1737229395871\": { \"type\": \"Text\", \"data\": { \"style\": { \"fontWeight\": \"normal\", \"padding\": { \"top\": 16, \"bottom\": 16, \"right\": 24, \"left\": 24 } }, \"props\": { \"text\": \"We’re glad to have you with us at {{ pagename }}!\" } } }, \"block-1737229536738\": { \"type\": \"Text\", \"data\": { \"style\": { \"fontWeight\": \"normal\", \"padding\": { \"top\": 16, \"bottom\": 16, \"right\": 24, \"left\": 24 } }, \"props\": { \"text\": \"To finish subscribing to our emails, just click the button below. You can unsubscribe anytime if you change your mind.\" } } }, \"block-1737229551815\": { \"type\": \"Button\", \"data\": { \"style\": { \"fontWeight\": \"bold\", \"textAlign\": \"center\", \"padding\": { \"top\": 16, \"bottom\": 16, \"right\": 24, \"left\": 24 } }, \"props\": { \"buttonBackgroundColor\": \"#4F46E5\", \"fullWidth\": true, \"text\": \"Subscribe!\", \"url\": \"{{ hostname }}/subscribe/optin?contactUUID={{ contactUUID }}\" } } } }", "Confirm your email address")

    exec(conn, sql("INSERT INTO settings (page_name, hostname, optin_email) VALUES (?, ?, ?) ON CONFLICT DO NOTHING;"), "Nimletter, drip it!", "https://nimletter.com", 1)

proc databaseDelete*() =
  pg.withConnection conn:
    when defined(DB_SQLITE):
      exec(conn, sql("PRAGMA writable_schema = 1;"))
      exec(conn, sql("delete from sqlite_master where type in ('table', 'index', 'trigger');"))
      exec(conn, sql("PRAGMA writable_schema = 0;"))
      exec(conn, sql("VACUUM;"))
    else:
      exec(conn, sql("DROP SCHEMA public CASCADE;"))
      exec(conn, sql("CREATE SCHEMA public;"))