
import
  std/[
    json,
    strutils
  ]

from std/os import getEnv

import
  mummy, mummy/routers,
  mummy_utils


import
  sqlbuilder


import
  ../database/database_connection,
  ../utils/auth,
  ../utils/validate_data,
  ../webhook/webhook_events




var settingsRouter*: Router


#
# Main
#
settingsRouter.get("/api/settings/main",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  var
    mainSettings: seq[string]
    optinEmailName = ""
  pg.withConnection conn:
    mainSettings = getRow(conn, sqlSelect(
      table = "settings",
      select = [
        "page_name",
        "hostname",
        "logo_url",
        "optin_email",
        "link_success",
      ],
      where = [
        "id = 1"
      ]
    ))
    if mainSettings.len > 3 and mainSettings[3].strip() != "":
      optinEmailName = getValue(conn, sqlSelect(
        table = "mails",
        select = ["name"],
        where = ["id = ?"]
      ), mainSettings[3])


  resp Http200, (
    %* [
      { "key": "pageName", "name": "Page Name", "value": mainSettings[0] },
      { "key": "hostname", "name": "Domain with HTTPS", "value": mainSettings[1] },
      { "key": "logoUrl", "name": "Logo URL", "value": mainSettings[2] },
      { "key": "optinEmailID", "name": "Optin Email ID", "value": mainSettings[3] },
      { "key": "linkSuccess", "name": "Link Success", "value": mainSettings[4] },
      { "key": "optinEmailName", "name": "Optin Email Name", "value": optinEmailName }
    ]
  )
)

settingsRouter.post("/api/settings/main",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    pageName = @"pageName"
    hostname = @"hostname"
    logoUrl = @"logoUrl"
    optinEmailID = @"optinEmailID"
    linkSuccess = @"linkSuccess"

  if pageName.strip() == "":
    resp Http400, "Page Name is required"

  if hostname.strip() == "":
    resp Http400, "Domain with HTTPS is required"

  if not optinEmailID.isValidInt():
    resp Http400, "Optin Email ID is required"

  #
  # Update database
  #
  pg.withConnection conn:
    exec(conn, sqlUpdate(
        table = "settings",
        data  = [
          "page_name",
          "hostname",
          "logo_url",
          "optin_email",
          "link_success"
        ],
        where = [
          "id = 1"
        ]),
        pageName,
        hostname,
        logoUrl,
        optinEmailID,
        linkSuccess
      )

  resp Http200, "Main settings saved"
)

#
# SMTP settings
#
settingsRouter.get("/api/settings/smtp",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401
  if c.rank != "admin":
    resp Http403, "You are not authorized to view SMTP settings"

  if getEnv("SMTP_HOST") != "":
    resp Http200, (
      %* [
          { "key": "smtpStorage", "name": "SMTP Storage", "value": "Environment variables" },
          { "key": "smtpHost", "name": "SMTP Host", "value": getEnv("SMTP_HOST") },
          { "key": "smtpPort", "name": "SMTP Port", "value": getEnv("SMTP_PORT") },
          { "key": "smtpUser", "name": "SMTP User", "value": getEnv("SMTP_USER") },
          { "key": "smtpFrom", "name": "SMTP From", "value": getEnv("SMTP_FROMEMAIL") },
          { "key": "smtpFromName", "name": "SMTP From Name", "value": getEnv("SMTP_FROMNAME") },
          { "key": "smtpPass", "name": "SMTP Password", "value": "" },
          { "key": "smtpMaxMailsPerSecond", "name": "Max Mails Per Second", "value": (if getEnv("SMTP_MAILSPERSECOND") == "": 1 else: getEnv("SMTP_MAILSPERSECOND").parseInt()) }
      ]
    )


  var smtpSettings: seq[string]
  pg.withConnection conn:
    smtpSettings = getRow(conn, sqlSelect(
      table = "smtp_settings",
      select = [
        "smtp_host",
        "smtp_port",
        "smtp_user",
        "smtp_fromemail",
        "smtp_fromname",
        "smtp_mailspersecond",
        "smtp_use_aws_ses"
      ]
    ))

  resp Http200, (
    %* [
      { "key": "smtpStorage", "name": "SMTP Storage", "value": "Database" },
      { "key": "smtpHost", "name": "SMTP Host", "value": smtpSettings[0] },
      { "key": "smtpPort", "name": "SMTP Port", "value": smtpSettings[1] },
      { "key": "smtpUser", "name": "SMTP User", "value": smtpSettings[2] },
      { "key": "smtpFrom", "name": "SMTP From", "value": smtpSettings[3] },
      { "key": "smtpFromName", "name": "SMTP From Name", "value": smtpSettings[4] },
      { "key": "smtpPass", "name": "SMTP Password", "value": "" },
      { "key": "smtpMaxMailsPerSecond", "name": "Max Mails Per Second", "value": smtpSettings[5] },
      { "key": "smtpUseAwsSes", "name": "Use AWS SES", "value": smtpSettings[6] == "t" or smtpSettings[6] == "true" }
    ]
  )
)

settingsRouter.post("/api/settings/smtp",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401
  if c.rank != "admin":
    resp Http403, "You are not authorized to update SMTP settings"

  let
    smtpHost = @"smtpHost"
    smtpPort = @"smtpPort"
    smtpUser = @"smtpUser"
    smtpPass = @"smtpPass"
    smtpFrom = @"smtpFrom"
    smtpFromName = @"smtpFromName"
    smtpMaxMailsPerSecond = @"smtpMaxMailsPerSecond"
    smtpUseAwsSes = @"smtpUseAwsSes"

  if smtpHost.strip() == "":
    resp Http400, "SMTP Host is required"

  if smtpPort.strip() == "" or not smtpPort.isValidInt():
    resp Http400, "SMTP Port is required"

  if smtpUser.strip() == "":
    resp Http400, "SMTP User is required"

  if smtpPass.strip() == "":
    resp Http400, "SMTP Password is required"

  if smtpFrom.strip() == "":
    resp Http400, "SMTP From is required"

  if smtpMaxMailsPerSecond.strip() == "":
    resp Http400, "Max Mails Per Second is required"

  #
  # Delete existing row if it exists
  #
  pg.withConnection conn:
    exec(conn, sqlDelete(
        table = "smtp_settings"
      ))

  #
  # Insert into database
  #
  pg.withConnection conn:
    exec(conn, sqlInsert(
        table = "smtp_settings",
        data  = [
          "smtp_host",
          "smtp_port",
          "smtp_user",
          "smtp_password",
          "smtp_fromemail",
          "smtp_fromname",
          "smtp_mailspersecond",
          "smtp_use_aws_ses"
        ]),
        smtpHost,
        smtpPort,
        smtpUser,
        smtpPass,
        smtpFrom,
        smtpFromName,
        smtpMaxMailsPerSecond,
        @"smtpUseAwsSes" == "true"
      )

  resp Http200, "SMTP settings saved"
)



#
# API settings
#
settingsRouter.get("/api/settings/api",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  var apiSettings: seq[seq[string]]
  pg.withConnection conn:
    apiSettings = getAllRows(conn, sqlSelect(
      table = "api_keys",
      select = [
        "ident",
        "name",
        "count",
        "to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
        "to_char(updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
      ]
    ))

  var bodyJson = parseJson("[]")
  for api in apiSettings:
    bodyJson.add(
      %* {
        "id": api[0],
        "name": api[1],
        "count": api[2],
        "created_at": api[3],
        "updated_at": api[4]
      }
    )

  resp Http200, (
    %* {
      "data": bodyJson,
      "last_page": 1
    }
  )
)


settingsRouter.post("/api/settings/api/new",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    apiName = @"apiName"

  if apiName.strip() == "":
    resp Http400, "API Name is required"

  #
  # Insert into database
  #
  var key: string
  pg.withConnection conn:
    let id = insertID(conn, sqlInsert(
        table = "api_keys",
        data  = [
          "name",
        ]),
        apiName
      )

    key = getValue(conn, sqlSelect(
      table = "api_keys",
      select = [
        "key"
      ],
      where = [
        "id = ?"
      ]),
      $id
    )

  resp Http200, (
    %* {
      "key": key,
      "name": apiName
    }
  )
)


settingsRouter.post("/api/settings/api/update",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401
  if c.rank != "admin":
    resp Http403, "You are not authorized to update API settings"

  let
    ident = @"ident"

  if not ident.isValidUUID():
    resp Http400, "API ident is required"

  #
  # Update database
  #
  pg.withConnection conn:
    exec(conn, sqlUpdate(
        table = "api_keys",
        data  = [
          "key = uuid_generate_v4()"
        ],
        where = [
          "ident = ?"
        ]),
        ident
      )

  resp Http200, "API settings updated"
)


settingsRouter.delete("/api/settings/api/delete",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401
  if c.rank != "admin":
    resp Http403, "You are not authorized to delete API settings"

  let
    ident = @"ident"

  if not ident.isValidUUID():
    resp Http400, "API ident is required"

  #
  # Delete from database
  #
  pg.withConnection conn:
    exec(conn, sqlDelete(
        table = "api_keys",
        where = [
          "ident = ?"
        ]),
        ident
      )

  resp Http200, "API settings deleted"
)


#
# Webhook settings
#
settingsRouter.get("/api/settings/webhooks",
proc (request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  var webhookSettings: seq[seq[string]]
  pg.withConnection conn:
    webhookSettings = getAllRows(conn, sqlSelect(
      table = "webhooks",
      select = [
        "name",
        "url",
        "event",
        "to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
        "to_char(updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
        "id"
      ]
    ))

  var bodyJson = parseJson("[]")
  for webhook in webhookSettings:
    bodyJson.add(
      %* {
        "name": webhook[0],
        "url": webhook[1],
        "event": webhook[2],
        "created_at": webhook[3],
        "id": webhook[5]
      }
    )

  resp Http200, (
    %* {
      "data": bodyJson,
      "last_page": 1
    }
  )
)


settingsRouter.post("/api/settings/webhooks/new",
proc (request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    webhookName = @"webhookName"
    webhookURL = @"webhookURL"
    webhookEvent = @"webhookEvent"
    webhookHeaders = @"webhookHeaders"

  if webhookName.strip() == "":
    resp Http400, "Webhook Name is required"

  if webhookURL.strip() == "":
    resp Http400, "Webhook URL is required"

  if webhookEvent.strip() == "":
    resp Http400, "Webhook Event is required"

  try:
    discard parseEnum[WebhookEvent](webhookEvent)
  except ValueError:
    resp Http400, "Invalid Webhook Event"


  #
  # Insert into database
  #
  pg.withConnection conn:
    exec(conn, sqlInsert(
        table = "webhooks",
        data  = [
          "name",
          "url",
          "event",
          "headers"
        ]),
        webhookName,
        webhookURL,
        webhookEvent,
        webhookHeaders
      )

  resp Http200, "Webhook settings saved"
)


settingsRouter.post("/api/settings/webhooks/delete",
proc (request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401
  if c.rank != "admin":
    resp Http403, "You are not authorized to delete webhook settings"

  let
    ident = @"ident"

  if not ident.isValidInt():
    resp Http400, "Webhook ident is required"

  #
  # Delete from database
  #
  pg.withConnection conn:
    exec(conn, sqlDelete(
        table = "webhooks",
        where = [
          "id = ?"
        ]),
        ident
      )

  resp Http200, "Webhook settings deleted"
)
