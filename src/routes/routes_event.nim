import
  std/[
    json,
    strutils,
    times
  ]

import
  mummy, mummy/routers,
  mummy_utils

import
  sqlbuilder

import
  ../database/database_connection,
  ../database/database_queries,
  ../utils/auth,
  ../utils/contacts_utils,
  ../utils/list_utils,
  ../utils/validate_data



proc getUserIDfromEmail(email: string): string =
  pg.withConnection conn:
    return getValue(conn, sqlSelect(
      table = "contacts",
      select = ["id"],
      where = ["email = ?"]
    ), email)


proc getMailIDfromIdent(identifier: string): string =
  pg.withConnection conn:
    return getValue(conn, sqlSelect(
      table = "mails",
      select = ["id"],
      where = ["identifier = ?"]
    ), identifier)


var eventRouter*: Router

eventRouter.post("/api/event",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  when defined(dev):
    echo "Event called"

  var data: JsonNode
  try:
    data = parseJson(c.req.body)
  except:
    resp Http400, "Invalid JSON"

  var
    event: string
    email: string
    mail: string
    content: string
    subject: string
    delay: int

  try:
    event = data["event"].getStr()
    email = data["email"].getStr()
    mail    = if data.hasKey("mail"): data["mail"].getStr() else: "" # mail-identifier
    content = if data.hasKey("content"): data["content"].getStr() else: ""
    subject = if data.hasKey("subject"): data["subject"].getStr() else: ""
  except:
    resp Http400, "Invalid data, event = " & event & ", email = " & email & ", mail = " & mail

  try:
    delay = data["delay"].getInt()
  except:
    delay = 0




  #
  # Event
  #
  case event
  of "email-send":
    let userID = getUserIDfromEmail(email)
    if userID == "":
      resp Http400, "User not found"

    let mailID = if mail == "": "" else: getMailIDfromIdent(mail)

    pg.withConnection conn:
      if contactIsSuppressed(conn, userID):
        resp Http200, ( %* { "success": false, "message": "Contact has bounced or complained and cannot receive emails" } )

      # For a specific mailID
      if mailID != "":
        if getValue(conn, sqlSelect(
              table = "mails",
              select = [
                "mails.id"
              ],
              joinargs = [
                (table: "pending_emails", tableAs: "", on: @["pending_emails.mail_id = mails.id"])
              ],
              where = [
                "mails.id =",
                "mails.send_once = true",
                "pending_emails.user_id ="
              ],
              customSQL = "AND pending_emails.status = 'sent' LIMIT 1"
          ), mailID, userID) != "":
            resp Http200, ( %* { "success": false, "message": "Mail enforces send_once. Mail already sent." } )

        exec(conn, sqlInsert(
          table = "pending_emails",
          data  = [
            "user_id",
            "mail_id",
            "status",
            "scheduled_for",
            "trigger_type"
          ]),
            userID, mailID,
            "pending",
            $(now().utc + delay.minutes).format("yyyy-MM-dd HH:mm:ss"),
            "event-send"
          )

      # Free send
      else:
        exec(conn, sqlInsert(
          table = "pending_emails",
          data  = [
            "user_id",
            "status",
            "scheduled_for",
            "trigger_type",
            "manual_html",
            "manual_subject"
          ]),
            userID,
            "pending",
            $(now().utc + delay.minutes).format("yyyy-MM-dd HH:mm:ss"),
            "event-send",
            content,
            subject
          )

      resp Http200, ( %* { "success": true, "message": "Email scheduled" } )


  of "email-cancel":
    let userID = getUserIDfromEmail(email)
    if userID == "":
      resp Http400, "User not found"

    let mailID = getMailIDfromIdent(mail)
    if mail == "":
      resp Http400, "Mail identifier required"

    pg.withConnection conn:
      if execAffectedRows(conn, sqlUpdate(
        table = "pending_emails",
        data  = ["status = ?"],
        where = [
          "user_id =",
          "mail_id =",
          "status ="
        ],
      ), "cancelled", userID, mailID, "pending") > 0:
        resp Http200, ( %* { "success": true, "message": "Email cancelled" } )
      else:
        resp Http200, ( %* { "success": false, "message": "No pending email found" } )


  of "contact-create":
    let data = createContactManual(request.body)
    if not data.success:
      resp Http400, %* {
        "success": false,
        "message": data.msg
      }

    resp Http200, data.data


  of "contact-exists":
    let data = contactExists(request.body)
    if not data.success:
      resp Http400, %* {
        "success": false,
        "message": data.msg
      }

    resp Http200, data.data


  of "contact-update":
    let data = contactUpdate(request.body)
    if not data.success:
      resp Http400, %* {
        "success": false,
        "message": data.msg
      }

    resp Http200, data.data


  of "contact-meta":
    let data = contactUpdateMeta(request.body)
    if not data.success:
      resp Http400, %* {
        "success": false,
        "message": data.msg
      }

    resp Http200, data.data


  of "contact-add-to-list":
    let userID = getUserIDfromEmail(email)
    if userID == "":
      resp Http400, "User not found"
    let listID = listIDfromIdentifier(if data.hasKey("list"): data["list"].getStr() else: "")
    var flowStep = if data.hasKey("flow_step"): data["flow_step"].getInt() else: 1
    if listID == "":
      resp Http400, "List identifier required"
    if flowStep == 0:
      flowStep = 1

    let data = addContactToList(userID, listID, flowStep)
    if not data:
      resp Http400, %* {
        "success": false,
        "message": "Failed to add contact to list"
      }

    resp Http200, %* {
      "success": true,
      "message": "Contact added to list"
    }


  of "contact-remove-from-list":
    let userID = getUserIDfromEmail(email)
    if userID == "":
      resp Http400, "User not found"
    let listID = listIDfromIdentifier(if data.hasKey("list"): data["list"].getStr() else: "")
    if listID == "":
      resp Http400, "List identifier required"

    let data = contactRemoveFromList(userID, listID, "")
    if not data.success:
      resp Http400, %* {
        "success": false,
        "message": data.msg
      }

    resp Http200, data.data


  of "email-bounce":
    let data = contactBounce(request.body)
    if not data.success:
      resp Http400, %* {
        "success": false,
        "message": data.msg
      }

    resp Http200, data.data

  else:
    resp Http400, "Invalid event"

)