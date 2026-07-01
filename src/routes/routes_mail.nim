

import
  std/[
    json,
    random,
    strutils
  ]


import
  mummy, mummy/routers,
  mummy_utils


import
  sqlbuilder


import
  ../database/database_connection,
  ../email/email_connection,
  ../scheduling/schedule_mail,
  ../utils/auth,
  ../utils/validate_data


randomize()


proc formatTags(tags: string): seq[string] =
  for tag in tags.split(","):
    if tag.strip() != "":
      result.add(tag.strip())


var mailRouter*: Router

mailRouter.post("/api/mails/create",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  #
  # Get data
  #
  let
    name      = @"name"
    tags      = @"tags"
    category  = @"category"
    contentHTML = @"contentHTML"
    contentEditor = @"contentEditor"

  if name.strip() == "":
    resp Http400, "Name is required"

  var identifier: string
  for c in name:
    if c in {' ', '-', '_', 'A'..'Z', 'a'..'z', '0'..'9'}:
      if c == ' ':
        identifier.add("-")
      else:
        identifier.add(c)

  identifier = identifier.multiReplace([(" ", "-"), ("---", "-"), ("--", "-")]).subStr(0, 100).strip(chars={'-', '_'}) & "-" & $rand(1000000)

  #
  # Insert into database
  #
  var mailID: string
  pg.withConnection conn:
    mailID = $insertID(conn, sqlInsert(
        table = "mails",
        data  = [
          "name",
          "identifier",
          "tags",
          "category",
          "contentHTML",
          "contentEditor",
        ]),
        name,
        (name.toLowerAscii().replace(" ", "-").subStr(0, 100).strip(chars={'-', '_'})),
        "{" & formatTags(tags).join(",") & "}",
        category,
        contentHTML,
        contentEditor
      )

  resp Http200, (
    %* {
      "id": mailID
    }
  )
)


mailRouter.post("/api/mails/duplicate",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let mailID = @"mailID"

  if not mailID.isValidInt():
    resp Http400, "Invalid UUID"

  var mailData: seq[string]
  pg.withConnection conn:
    mailData = getRow(conn, sqlSelect(
        table   = "mails",
        select  = [
          "id",
          "name",
          "contentHTML",
          "contentEditor",
          "editorType",
          "tags",
          "category",
          "send_once",
          "subject",
          "identifier"
        ],
        where   = [
          "id = ?"
        ]),
      mailID)

  if mailData.len() == 0 or mailData[0] == "":
    resp Http404, "mail not found for UUID " & mailID

  var newMailID: string
  pg.withConnection conn:
    newMailID = $insertID(conn, sqlInsert(
        table = "mails",
        data  = [
          "name",
          "identifier",
          "contentHTML",
          "contentEditor",
          "editorType",
          "tags",
          "category",
          "send_once",
          "subject"
        ]),
      mailData[1],  # name
      mailData[9].toLowerAscii().replace(" ", "-").subStr(0, 100).strip(chars={'-', '_'}) & "-" & $rand(1000000),  # identifier
      mailData[2],  # contentHTML
      mailData[3],  # contentEditor
      mailData[4],  # editorType
      mailData[5],  # tags
      mailData[6],  # category
      mailData[7],  # send_once
      mailData[8],  # subject
    )

  resp Http200, (
    %* {
      "id": newMailID
    }
  )
)


mailRouter.get("/api/mails/get",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  #
  # Validate input
  #
  let
    mailID = @"mailID"

  if not mailID.isValidInt():
    resp Http400, "Invalid UUID"


  #
  # Get data
  #
  var mailData: seq[string]
  pg.withConnection conn:
    mailData = getRow(conn, sqlSelect(
        table   = "mails",
        select  = [
          "id",
          "name",
          "contentHTML",
          "contentEditor",
          "editorType",
          "tags",
          "category",
          "subject",
          "to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
          "to_char(updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
          "identifier",
          "send_once"
          ],
        where   = [
          "id = ?"
        ]),
      mailID)

  #
  # Check return
  #
  if mailData.len() == 0 or mailData[0] == "":
    resp Http404, "mail not found for UUID " & mailID


  resp Http200, (
    %* {
      "id": mailData[0],
      "name": mailData[1],
      "contentHTML": mailData[2],
      "contentEditor": mailData[3],
      "editorType": mailData[4],
      "tags": (if mailData[5] == "{}": @[] else: mailData[5].strip(chars = {'{', '}'}).split(",")),
      "category": mailData[6],
      "subject": mailData[7],
      "created_at": mailData[8],
      "updated_at": mailData[9],
      "identifier": mailData[10],
      "send_once": mailData[11] == "t"
    }
  )
)


mailRouter.post("/api/mails/update",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  #
  # Get data
  #
  let
    mailID  = @"mailID"
    name      = @"name".strip()
    identifier = (if @"identifier" == "": name.toLowerAscii().replace(" ", "-").subStr(0, 100).strip(chars={'-', '_'}) else: @"identifier".replace(" ", "-").subStr(0, 100).strip(chars={'-', '_'}))
    tags      = @"tags"
    category  = @"category"
    sendOnce  = (if @"sendOnce" == "true": true else: false)
    contentHTML = @"contentHTML"
    contentEditor = @"contentEditor"
    editorType = (if @"editorType" in ["html", "emailbuilder"]: @"editorType" else: "html")
    skipContent = (@"skipContent" == "true")
    subject = @"subject"

  if not mailID.isValidInt():
    resp Http400, "Invalid UUID"

  if name == "":
    resp Http400, "Name is required"

  var hit = false
  pg.withConnection conn:

    if not skipContent:
      hit = execAffectedRows(conn, sqlUpdate(
          table = "mails",
          data  = [
            "name",
            "identifier",
            "tags",
            "category",
            "contentHTML",
            "contentEditor",
            "editorType",
            "send_once",
            "subject"
          ],
          where = [
            "id = ?"
          ]),
        name,
        identifier,
        "{" & formatTags(tags).join(",") & "}",
        category,
        contentHTML,
        contentEditor,
        editorType,
        sendOnce,
        subject,
        mailID
      ) > 0

    else:
      hit = execAffectedRows(conn, sqlUpdate(
          table = "mails",
          data  = [
            "name",
            "identifier",
            "tags",
            "category",
            "editorType",
            "send_once",
            "subject"
          ],
          where = [
            "id = ?"
          ]),
        name,
        identifier,
        "{" & formatTags(tags).join(",") & "}",
        category,
        editorType,
        sendOnce,
        subject,
        mailID
      ) > 0

  if not hit:
    resp Http404, "Mail not found for UUID " & mailID

  resp Http200
)


mailRouter.delete("/api/mails/delete",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let mailUUID = @"mail_uuid"

  if not mailUUID.isValidUUID():
    resp Http400, "Invalid UUID"

  var hit = false
  pg.withConnection conn:
    let ident = getValue(conn, sqlSelect(
        table = "mails",
        select = ["identifier"],
        where = ["uuid = ?"]
      ),
      mailUUID)

    if ident == "double-opt-in":
      resp Http400, "Cannot delete double-opt-in mail"

    hit = execAffectedRows(conn, sqlDelete(
        table = "mails",
        where = [
          "uuid = ?"
        ]),
      mailUUID
    ) > 0

  if not hit:
    resp Http404, "Mail not found for UUID " & mailUUID

  resp Http200
)


mailRouter.get("/api/mails/all",
proc(request: Request) =
  ## Returns mails list. Pass ?analytics=true to include engagement stats
  ## (opens, clicks, bounce rates). Omitting analytics skips the expensive
  ## correlated subqueries, keeping the default view fast on large datasets.
  createTFD()
  if not c.loggedIn: resp Http401

  let
    limit        = (if @"size" == "": 2000 else: @"size".parseInt())
    offset       = (if @"page" == "": 0 elif @"page".parseInt() == 1: 0 else: (@"page".parseInt() - 1) * limit)
    analyticsMode = @"analytics" == "true"

  var
    mails: seq[seq[string]]
    mailsCount: int

  pg.withConnection conn:
    if analyticsMode:
      # Full query including per-mail engagement counts — slower on large datasets
      mails = getAllRows(conn, sqlSelect(
        table   = "mails",
        select  = [
          "mails.id",
          "mails.name",
          "mails.subject",
          "array_to_string(mails.tags, ',')",
          "mails.category",
          "to_char(mails.created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
          "to_char(mails.updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
          "COUNT(DISTINCT pending_emails.id) FILTER (WHERE pending_emails.status = 'sent') as sent_count",
          "COUNT(DISTINCT pending_emails.id) FILTER (WHERE pending_emails.status = 'pending') as pending_count",
          "(SELECT COUNT(DISTINCT email_opens.pending_email_id) FROM email_opens INNER JOIN pending_emails pe ON email_opens.pending_email_id = pe.id WHERE pe.mail_id = mails.id) as opened_count",
          "(SELECT COUNT(DISTINCT email_clicks.pending_email_id) FROM email_clicks INNER JOIN pending_emails pe ON email_clicks.pending_email_id = pe.id WHERE pe.mail_id = mails.id) as clicked_count",
          "(SELECT COUNT(DISTINCT email_bounces.pending_email_id) FROM email_bounces INNER JOIN pending_emails pe ON email_bounces.pending_email_id = pe.id WHERE pe.mail_id = mails.id) as bounced_count",
          "(SELECT COUNT(DISTINCT email_complaints.pending_email_id) FROM email_complaints INNER JOIN pending_emails pe ON email_complaints.pending_email_id = pe.id WHERE pe.mail_id = mails.id) as complained_count",
          "mails.identifier"
        ],
        joinargs = [
          (table: "pending_emails", tableAs: "", on: @["pending_emails.mail_id = mails.id"])
        ],
        customSQL = "GROUP BY mails.category, mails.name, mails.subject, mails.id, mails.subject, mails.tags, mails.created_at, mails.updated_at, mails.identifier ORDER BY mails.category, mails.name ASC LIMIT $1 OFFSET $2".format(
          $limit,
          $offset
        )
      ))
    else:
      # Simple query — sent/pending counts only, no correlated subqueries for opens/clicks/rates
      mails = getAllRows(conn, sqlSelect(
        table   = "mails",
        select  = [
          "mails.id",
          "mails.name",
          "mails.subject",
          "array_to_string(mails.tags, ',')",
          "mails.category",
          "to_char(mails.created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
          "to_char(mails.updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
          "COUNT(DISTINCT pending_emails.id) FILTER (WHERE pending_emails.status = 'sent') as sent_count",
          "COUNT(DISTINCT pending_emails.id) FILTER (WHERE pending_emails.status = 'pending') as pending_count",
          "mails.identifier"
        ],
        joinargs = [
          (table: "pending_emails", tableAs: "", on: @["pending_emails.mail_id = mails.id"])
        ],
        customSQL = "GROUP BY mails.category, mails.name, mails.subject, mails.id, mails.tags, mails.created_at, mails.updated_at, mails.identifier ORDER BY mails.category, mails.name ASC LIMIT $1 OFFSET $2".format(
          $limit,
          $offset
        )
      ))

    mailsCount = getRow(conn, sqlSelect(
      table   = "mails",
      select  = ["count(*)"]
      )
    )[0].parseInt()

  var bodyJson = parseJson("[]")

  for mail in mails:
    if analyticsMode:
      let sentCount = mail[7].parseInt()
      bodyJson.add(
        %* {
          "id": mail[0],
          "name": mail[1],
          "subject": mail[2],
          "tags": mail[3].split(","),
          "category": mail[4],
          "created_at": mail[5],
          "updated_at": mail[6],
          "sent_count":       sentCount,
          "pending_count":    mail[8].parseInt(),
          "opened_count":     mail[9].parseInt(),
          "clicked_count":    mail[10].parseInt(),
          "bounced_count":    mail[11].parseInt(),
          "complained_count": mail[12].parseInt(),
          # Rates are unique counts / sent * 100 (float, one decimal displayed in UI)
          "open_rate":    if sentCount > 0: (mail[9].parseInt().float  * 100.0 / sentCount.float) else: 0.0,
          "click_rate":   if sentCount > 0: (mail[10].parseInt().float * 100.0 / sentCount.float) else: 0.0,
          "bounce_rate":  if sentCount > 0: (mail[11].parseInt().float * 100.0 / sentCount.float) else: 0.0,
          "identifier": mail[13]
        }
      )
    else:
      bodyJson.add(
        %* {
          "id": mail[0],
          "name": mail[1],
          "subject": mail[2],
          "tags": mail[3].split(","),
          "category": mail[4],
          "created_at": mail[5],
          "updated_at": mail[6],
          "sent_count":   mail[7].parseInt(),
          "pending_count": mail[8].parseInt(),
          "identifier": mail[9]
        }
      )

  resp Http200, (
    %* {
      "data": bodyJson,
      "count": mailsCount,
      "size": limit,
      "page": offset,
      "last_page": if mailsCount == 0: 0 elif (mailsCount/limit) < 1.0: 1 else: split($(mailsCount/limit + 1), ".")[0].parseInt()
    }
  )
)


mailRouter.get("/api/mails/log",
proc(request: Request) =
  ## Getting the last 2000 sent emails from pending_emails
  createTFD()
  if not c.loggedIn: resp Http401

  let
    limit = (if @"size" == "": 2000 else: @"size".parseInt())
    offset = (if @"page" == "": 0 elif @"page".parseInt() == 1: 0 else: (@"page".parseInt() - 1) * limit)


  var
    orderby = "ORDER BY pending_emails.scheduled_for DESC, pending_emails.created_at DESC"
    filterStatus = @["pending_emails.status = 'sent'"]

  if @"status" == "all":
    filterStatus = @[]
    orderby = "ORDER BY pending_emails.created_at DESC"
  elif @"status" == "pending":
    filterStatus = @["pending_emails.status = 'pending'"]
    orderby = "ORDER BY pending_emails.scheduled_for DESC, pending_emails.created_at DESC"
  elif @"status" == "sent":
    filterStatus = @["pending_emails.status = 'sent'"]
    orderby = "ORDER BY pending_emails.sent_at DESC"

  var
    mails: seq[seq[string]]
    mailsCount: int

  pg.withConnection conn:
    mails = getAllRows(conn, sqlSelect(
        table   = "pending_emails",
        select  = [
        "pending_emails.id",
        "pending_emails.user_id",
        "pending_emails.list_id",
        "pending_emails.flow_id",
        "pending_emails.flow_step_id",
        "pending_emails.trigger_type",
        "to_char(pending_emails.scheduled_for, 'YYYY-MM-DD HH24:MI:SS TZ') as scheduled_for",
        "pending_emails.status",
        "pending_emails.message_id",
        "pending_emails.sent_at",
        "to_char(pending_emails.created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
        "to_char(pending_emails.updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
        "contacts.email as user_email",
        "contacts.meta->>'country' AS country",
        "lists.name as list_name",
        "flows.name as flow_name",
        "flow_steps.name as flow_step_name",
        "CASE WHEN EXISTS (SELECT 1 FROM email_opens WHERE email_opens.pending_email_id = pending_emails.id) THEN 'true' ELSE 'false' END as opened",
        "CASE WHEN EXISTS (SELECT 1 FROM email_clicks WHERE email_clicks.pending_email_id = pending_emails.id) THEN 'true' ELSE 'false' END as clicked"
        ],
        joinargs = [
        (table: "contacts", tableAs: "", on: @["contacts.id = pending_emails.user_id"]),
        (table: "lists", tableAs: "", on: @["lists.id = pending_emails.list_id"]),
        (table: "flows", tableAs: "", on: @["flows.id = pending_emails.flow_id"]),
        (table: "flow_steps", tableAs: "", on: @["flow_steps.id = pending_emails.flow_step_id"])
        ],
        where = filterStatus,
        customSQL = orderby & " LIMIT $1 OFFSET $2".format(
        $limit,
        $offset
        )
      ))

    mailsCount = getRow(conn, sqlSelect(
      table   = "pending_emails",
      select  = ["count(*)"]
      )
    )[0].parseInt()


  var bodyJson = parseJson("[]")
  for mail in mails:
    bodyJson.add(
      %* {
        "id": mail[0],
        "user_id": mail[1],
        "list_id": mail[2],
        "flow_id": mail[3],
        "flow_step_id": mail[4],
        "trigger_type": mail[5],
        "scheduled_for": mail[6],
        "status": mail[7],
        "message_id": mail[8],
        "sent_at": mail[9],
        "created_at": mail[10],
        "updated_at": mail[11],
        "user_email": mail[12],
        "country": mail[13],
        "list_name": mail[14],
        "flow_name": mail[15],
        "flow_step_name": mail[16],
        "opened": mail[17],
        "clicked": mail[18]
      }
    )

  resp Http200, (
    %* {
      "data": bodyJson,
      "count": mailsCount,
      "size": limit,
      "page": offset,
      "last_page": if mailsCount == 0: 0 elif (mailsCount/limit) < 1.0: 1 else: split($(mailsCount/limit + 1), ".")[0].parseInt()
    }
  )
)


mailRouter.post("/api/mails/send",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    mailID = @"mailID"
    listID = @"listID"
    email  = @"email"

  if mailID == "":
    resp Http400, "Mail ID is required"

  var
    mailData: seq[string]
    contactData: seq[string]
    listExists = false
    mailCategory: string

  pg.withConnection conn:
    # Check if email is archived before proceeding
    mailCategory = getValue(conn, sqlSelect(
        table   = "mails",
        select  = [
          "category"
          ],
        where   = [
          "id = ?"
        ]),
      mailID)

    if mailCategory == "archived":
      resp Http400, "Cannot send mails that are archived. Change the mail status. (mail ID " & mailID & ")"

    mailData = getRow(conn, sqlSelect(
        table   = "mails",
        select  = [
          "id",
          "contentHTML",
          "subject"
          ],
        where   = [
          "id = ?"
        ]),
      mailID)

    if email.isValidEmail():
      contactData = getRow(conn, sqlSelect(
          table   = "contacts",
          select  = [
            "id",
            "email"
            ],
          where   = [
            "email = ?"
          ]),
        email)

    elif listID != "":
      listExists = getValue(conn, sqlSelect(
          table   = "lists",
          select  = [
            "id",
            ],
          where   = [
            "id = ?"
          ]),
        listID) != ""

  if mailData[0] == "":
    resp Http404, "Mail not found for ID " & mailID

  if email.isValidEmail():
    let isContact = contactData[0] != ""
    discard sendMailMimeNow(
      contactID = (if isContact: contactData[0] else: "0"),
      subject = mailData[2],
      message = mailData[1],
      recipient = (if isContact: contactData[1] else: email),
    )

    resp Http200, "Mail sent to " & email

  elif listExists:
    let (success, msg) = createPendingEmailToAllListContacts(listID, mailID)
    if not success:
      resp Http400, msg

    resp Http200, "Mail sent to listID: " & listID

)

# Check if an email is used in any flow steps
mailRouter.get("/api/mails/check_flows",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let mailID = @"mailID"

  if not mailID.isValidInt():
    resp Http400, "Invalid mail ID"

  var flowSteps: seq[seq[string]]
  pg.withConnection conn:
    flowSteps = getAllRows(conn, sqlSelect(
      table   = "flow_steps",
      select  = [
        "flow_steps.id",
        "flow_steps.flow_id",
        "flow_steps.step_number",
        "flows.name as flow_name"
      ],
      joinargs = [
        (table: "flows", tableAs: "", on: @["flows.id = flow_steps.flow_id"])
      ],
      where   = ["flow_steps.mail_id = ?"]
    ), mailID)

  var respData = parseJson("[]")
  for row in flowSteps:
    respData.add(
      %* {
        "flow_step_id": row[0],
        "flow_id": row[1],
        "step_number": row[2],
        "flow_name": row[3]
      }
    )

  resp Http200, (
    %* {
      "used_in_flows": flowSteps.len > 0,
      "flow_steps": respData,
      "count": flowSteps.len
    }
  )
)


mailRouter.get("/api/mails/analytics",
proc(request: Request) =
  ## On-demand enriched analytics for a single mail template.
  ## Returns CTOR, avg time-to-open, device/client breakdown,
  ## top clicked links, and opens by hour-of-day.
  ## Designed for lazy loading — not included in /api/mails/all.
  createTFD()
  if not c.loggedIn: resp Http401

  let mailIDStr = @"mailID"
  if mailIDStr == "":
    resp Http400, "mailID is required"

  var mailID: int
  try:
    mailID = mailIDStr.parseInt()
  except ValueError:
    resp Http400, "mailID must be an integer"

  var
    uniqueOpensStr:  string
    uniqueClicksStr: string
    avgTimeStr:      string
    deviceRows:      seq[seq[string]]
    topLinkRows:     seq[seq[string]]
    openHourRows:    seq[seq[string]]

  pg.withConnection conn:
    uniqueOpensStr = getValue(conn, sqlSelect(
      table    = "email_opens",
      select   = ["COUNT(DISTINCT email_opens.pending_email_id)"],
      joinargs = [(table: "pending_emails", tableAs: "", on: @["pending_emails.id = email_opens.pending_email_id"])],
      customSQL = "WHERE pending_emails.mail_id = $1".format($mailID)
    ))

    uniqueClicksStr = getValue(conn, sqlSelect(
      table    = "email_clicks",
      select   = ["COUNT(DISTINCT email_clicks.pending_email_id)"],
      joinargs = [(table: "pending_emails", tableAs: "", on: @["pending_emails.id = email_clicks.pending_email_id"])],
      customSQL = "WHERE pending_emails.mail_id = $1".format($mailID)
    ))

    # Average minutes from send to first open; ignores rows where sent_at is missing
    # or the open timestamp is invalid (negative delta indicates data anomaly).
    avgTimeStr = getValue(conn, sqlSelect(
      table    = "email_opens",
      select   = ["COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (email_opens.opened_at - pending_emails.sent_at)) / 60))::text, '0')"],
      joinargs = [(table: "pending_emails", tableAs: "", on: @["pending_emails.id = email_opens.pending_email_id"])],
      customSQL = "WHERE pending_emails.mail_id = $1 AND pending_emails.sent_at IS NOT NULL AND email_opens.opened_at > pending_emails.sent_at".format($mailID)
    ))

    # Classify device_info (raw User-Agent) into four buckets.
    # Priority: email client > mobile > desktop > unknown.
    # Note: Gmail and many security proxies strip UA detail, so 'unknown' may be high.
    deviceRows = getAllRows(conn, sqlSelect(
      table    = "email_opens",
      select   = [
        """CASE
          WHEN email_opens.device_info ILIKE '%Outlook%' OR email_opens.device_info ILIKE '%Windows Mail%' THEN 'email_client'
          WHEN email_opens.device_info ILIKE '%iPhone%'  OR email_opens.device_info ILIKE '%iPad%' OR email_opens.device_info ILIKE '%Android%' THEN 'mobile'
          WHEN email_opens.device_info ILIKE '%Macintosh%' OR email_opens.device_info ILIKE '%Windows NT%' OR email_opens.device_info ILIKE '%X11%' THEN 'desktop'
          ELSE 'unknown'
        END AS device_category""",
        "COUNT(*) AS cnt"
      ],
      joinargs = [(table: "pending_emails", tableAs: "", on: @["pending_emails.id = email_opens.pending_email_id"])],
      customSQL = "WHERE pending_emails.mail_id = $1 GROUP BY device_category".format($mailID)
    ))

    topLinkRows = getAllRows(conn, sqlSelect(
      table    = "email_clicks",
      select   = ["email_clicks.link_url", "COUNT(*) AS click_count"],
      joinargs = [(table: "pending_emails", tableAs: "", on: @["pending_emails.id = email_clicks.pending_email_id"])],
      customSQL = "WHERE pending_emails.mail_id = $1 GROUP BY email_clicks.link_url ORDER BY click_count DESC LIMIT 10".format($mailID)
    ))

    openHourRows = getAllRows(conn, sqlSelect(
      table    = "email_opens",
      select   = ["EXTRACT(HOUR FROM email_opens.opened_at)::int AS hour", "COUNT(*) AS cnt"],
      joinargs = [(table: "pending_emails", tableAs: "", on: @["pending_emails.id = email_opens.pending_email_id"])],
      customSQL = "WHERE pending_emails.mail_id = $1 GROUP BY hour ORDER BY hour ASC".format($mailID)
    ))

  let
    uniqueOpens  = uniqueOpensStr.parseInt()
    uniqueClicks = uniqueClicksStr.parseInt()
    ctorVal      = if uniqueOpens > 0: (uniqueClicks.float * 100.0 / uniqueOpens.float) else: 0.0

  var deviceJson = %* {"mobile": 0, "email_client": 0, "desktop": 0, "unknown": 0}
  for row in deviceRows:
    let cat = row[0]
    if cat in ["mobile", "email_client", "desktop", "unknown"]:
      deviceJson[cat] = %row[1].parseInt()

  var topLinksJson = parseJson("[]")
  for row in topLinkRows:
    topLinksJson.add(%* {"url": row[0], "click_count": row[1].parseInt()})

  # Build full 24-hour distribution; hours with zero opens are included as 0
  var openHoursArr: array[24, int]
  for row in openHourRows:
    let h = row[0].parseInt()
    if h >= 0 and h <= 23:
      openHoursArr[h] = row[1].parseInt()

  var openHoursJson = parseJson("[]")
  for h in 0..23:
    openHoursJson.add(%* {"hour": h, "count": openHoursArr[h]})

  resp Http200, (
    %* {
      "mail_id":                  mailID,
      "unique_opens":             uniqueOpens,
      "unique_clicks":            uniqueClicks,
      "ctor":                     ctorVal,
      "avg_time_to_open_minutes": (if avgTimeStr == "": 0 else: avgTimeStr.parseInt()),
      "device_breakdown":         deviceJson,
      "top_links":                topLinksJson,
      "open_hours":               openHoursJson
    }
  )
)