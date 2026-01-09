


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
  mummy, mummy/routers,
  mummy_utils


import
  sqlbuilder


import
  ../database/database_connection,
  ../email/email_optin,
  ../scheduling/schedule_mail,
  ../utils/auth,
  ../utils/contacts_utils,
  ../utils/list_utils,
  ../utils/validate_data,
  ../webhook/webhook_events





var contactsRouter*: Router

contactsRouter.post("/api/contacts/create",
proc(request: Request) =
  createTFD()
  if not c.loggedIn:
    resp Http401

  let data = createContactManual(request.body)

  if not data.success:
    resp Http400, data.msg

  resp Http200, data.data
)


contactsRouter.post("/api/contacts/update",
proc(request: Request) =
  createTFD()
  if not c.loggedIn:
    resp Http401

  let data = contactUpdate(request.body)
  if not data.success:
    resp Http400, data.msg

  resp Http200, data.data

  # let
  #   contactID = @"contactID"
  #   email  = @"email"
  #   name   = @"name"
  #   status = parseEnum[UserStatus](@"status", disabled)
  #   requiresDoubleOptIn = (@"requiresDoubleOptIn" == "true")
  #   doubleOptIn = (@"doubleOptIn" == "true")
  #   meta   = @"meta"

  # if not contactID.isValidInt() and not email.isValidEmail():
  #   resp Http400, "Invalid user ID or EMAIL"

  # if email.len() > 255 or not email.isValidEmail():
  #   resp Http400, "Invalid email"

  # if meta.len() > 0:
  #   try:
  #     discard parseJson(meta)
  #   except:
  #     resp Http400, "Invalid meta JSON"

  # pg.withConnection conn:
  #   exec(conn, sqlUpdate(
  #       table = "contacts",
  #       data  = [
  #         "updated_at",
  #         "email",
  #         "name",
  #         "status",
  #         "requires_double_opt_in",
  #         "double_opt_in",
  #         "meta",
  #       ],
  #       where = [
  #         (if contactID != "":
  #           "id = ?"
  #         else:
  #           "email = ?")
  #       ]
  #     ),
  #       $now().utc,
  #       email, name, $status, $requiresDoubleOptIn, $doubleOptIn, meta,
  #       (if contactID != "":
  #         contactID
  #       else:
  #         email)
  #     )

  # if status != disabled:
  #   if not requiresDoubleOptIn or doubleOptIn:
  #     moveFromPendingToSubscription(contactID)
  # else:
  #   # Cancel all pending emails
  #   pg.withConnection conn:
  #     exec(conn, sqlUpdate(
  #         table = "pending_emails",
  #         data  = [
  #           "status = 'cancelled'",
  #           "scheduled_for = NULL",
  #           "updated_at = ?"
  #         ],
  #         where = ["user_id = ?", "status = 'pending'"]),
  #       $now().utc, contactID)

  #   # # Remove from all lists
  #   # exec(conn, sqlDelete(
  #   #     table = "subscriptions",
  #   #     where = ["user_id = ?"]),
  #   #   contactID)

  # let data = %* {
  #     "success": true,
  #     "id": contactID,
  #     "requiresDoubleOptIn": requiresDoubleOptIn,
  #     "email": email,
  #     "name": name,
  #     "status": status,
  #     "meta": (if meta != "": parseJson(meta) else: parseJson("{}")),
  #     "event": "contact_updated"
  #   }

  # parseWebhookEvent(contact_updated, data)

  # resp Http200
)


contactsRouter.post("/api/contacts/meta/@action",
proc(request: Request) =
  ## meta is JSONB. If action = add, add new, if action = remove, remove key
  createTFD()
  if not c.loggedIn: resp Http401

  var
    contactID = @"contactID"
    email     = @"email"
    action    = @"action"
    key       = @"key"
    value     = @"value"

  if not contactID.isValidInt() and not email.isValidEmail():
    resp Http400, "Invalid user ID or EMAIL"

  if action != "add" and action != "remove":
    resp Http400, "Invalid action"

  if key.len() == 0:
    resp Http400, "Invalid key"

  if action == "add":
    pg.withConnection conn:
      exec(conn, sqlUpdate(
          table = "contacts",
          data  = [
            "meta = jsonb_set(meta, ?::text[], to_jsonb(?))",
            "updated_at",
          ],
          where = [
            (if contactID != "":
              "id = ?"
            else:
              "email = ?")
          ]
        ),
        "{" & key & "}", value,
        $now().utc,
        (if contactID != "":
          contactID
        else:
          email)
      )

  elif action == "remove":
    pg.withConnection conn:
      exec(conn, sqlUpdate(
          table = "contacts",
          data  = [
            "meta = meta - ?",
            "updated_at",
          ],
          where = [
            (if contactID != "":
              "id = ?"
            else:
              "email = ?")
          ]
        ),
        key,
        $now().utc,
        (if contactID != "":
          contactID
        else:
          email)
      )

  resp Http200
)


contactsRouter.post("/api/contacts/list/add",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    userID = @"contactID"
    listID = @"listID"
    listType = @"listType"

  if not userID.isValidInt():
    resp Http400, "Invalid user ID"

  if not listID.isValidInt():
    resp Http400, "Invalid list ID"



  if listType == "pending":
    pg.withConnection conn:
      exec(conn, sqlUpdate(
          table = "contacts",
          data  = [
            "pending_lists = array_append(pending_lists, ?)",
            "updated_at",
          ],
          where = ["id = ?"]
        ),
        listID,
        $now().utc,
        userID
      )

    resp Http200


  if not addContactToList(userID, listID):
    resp Http400, "Error subscribing user"

  resp Http200
)


contactsRouter.post("/api/contacts/list/remove",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    userID = @"contactID"
    listID = @"listID"
    listType = @"listType"

  let data = contactRemoveFromList(userID, listID, listType)
  if not data.success:
    resp Http400, data.msg

  resp Http200
)


contactsRouter.delete("/api/contacts/delete",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let userUUID = @"userUUID"

  if not userUUID.isValidUUID():
    resp Http400, "Invalid user UUID"

  pg.withConnection conn:
    exec(conn, sqlDelete(
        table = "contacts",
        where = ["uuid = ?"]),
      userUUID)

  resp Http200
)


contactsRouter.get("/api/contacts/get",
proc(request: Request) =
  createTFD()
  if not c.loggedIn:
    resp Http401

  if not @"contactID".isValidInt():
    resp Http400, "Invalid user ID"

  let
    contactID = @"contactID"

  var
    contact: seq[string]
    subscriptions: seq[seq[string]]
    pendingList: seq[seq[string]]

  pg.withConnection conn:
    #
    # Get user
    #
    contact = getRow(conn, sqlSelect(
      table = "contacts",
      select = [
        "contacts.id",
        "contacts.uuid",
        "contacts.email",
        "contacts.name",
        "contacts.requires_double_opt_in",
        "contacts.double_opt_in",
        "contacts.double_opt_in_data",
        "contacts.bounced_at",
        "contacts.complained_at",
        "contacts.created_at",
        "contacts.updated_at",
        "contacts.meta",
        "contacts.status",
        "contacts.pending_lists",
        "contacts.has_unsubscribed",
        "contacts.unsubscribed_at",
        "contacts.unscribed_from_lists"
      ],
      where = ["contacts.id = ?"],
      customSQL = "ORDER BY contacts.created_at"
      ), contactID)


    #
    # Get subscriptions
    #
    subscriptions = getAllRows(conn, sqlSelect(
      table = "subscriptions",
      select = [
        "subscriptions.id",
        "subscriptions.list_id",
        "subscriptions.subscribed_at",
        "lists.name",
      ],
      joinargs = [
        (table: "lists", tableAs: "", on: @["subscriptions.list_id = lists.id"]),
      ],
      where = ["subscriptions.user_id = ?"],
      customSQL = "ORDER BY lists.name"
      ), contactID)


    #
    # Get pending lists
    #
    if contact[13] != "":
      pendingList = getAllRows(conn, sqlSelect(
        table = "lists",
        select = [
          "lists.id",
          "lists.name",
          "lists.description",
          "array_to_string(lists.flow_ids, ',') as flows",
          "lists.created_at",
          "lists.updated_at",
        ],
        where = ["lists.id = ANY(?::int[])"],
        customSQL = "ORDER BY lists.name",
        ), contact[13])


  if contact.len == 0:
    resp Http404, "User not found"

  #
  # Build JSON response
  #
  var subscriptionsJson = parseJson("[]")
  for subscription in subscriptions:
    subscriptionsJson.add( %* {
      "id": subscription[0],
      "list_id": subscription[1],
      "subscribed_at": subscription[2],
      "list_name": subscription[3],
    })

  var pendingListsJson = parseJson("[]")
  for pending in pendingList:
    pendingListsJson.add( %* {
      "id": pending[0],
      "list_name": pending[1],
      "description": pending[2],
      "flow_id": pending[3],
      "created_at": pending[4],
      "updated_at": pending[5],
    })

  var bodyJson = parseJson("[]")
  bodyJson.add( %* {
    "id": contact[0],
    "uuid": contact[1],
    "email": contact[2],
    "name": contact[3],
    "requires_double_opt_in": (contact[4] == "t"),
    "double_opt_in": (contact[5] == "t"),
    "double_opt_in_data": (if contact[6] != "": parseJson(contact[6]) else: parseJson("[]")),
    "bounced_at": contact[7],
    "complained_at": contact[8],
    "created_at": contact[9],
    "updated_at": contact[10],
    "meta": (if contact[11] != "": parseJson(contact[11]) else: parseJson("{}")),
    "status": contact[12],
    "pending_lists": pendingListsJson,
    "subscriptions": subscriptionsJson,
    "has_unsubscribed": (contact[13] == "t"),
    "unsubscribed_at": contact[14],
    "unscribed_from_lists": contact[15],
  })

  resp Http200, (
    %* {
      "data": bodyJson,
      "count": 1,
      "last_page": 1
    }
  )
)


contactsRouter.get("/api/contacts/exist",
proc(request: Request) =
  createTFD()
  if not c.loggedIn:
    resp Http401

  let data = contactExists(request.body)
  if not data.success:
    resp Http400, data.msg

  resp Http200, data.data

)


contactsRouter.get("/api/contacts/get/activity",
proc(request: Request) =
  ## Data from each of the tables:
  ## pending_emails, email_clicks, email_opens, email_bounces, email_complaints
  createTFD()
  if not c.loggedIn: resp Http401

  if not @"contactID".isValidInt():
    resp Http400, "Invalid user ID"

  let contactID = @"contactID"

  var
    pendingEmails: seq[seq[string]]
    emailClicks: seq[seq[string]]
    emailOpens: seq[seq[string]]
    emailBounces: seq[seq[string]]
    emailComplaints: seq[seq[string]]


  pg.withConnection conn:

    pendingEmails = getAllRows(conn, sqlSelect(
      table = "pending_emails",
      select = [
        "pending_emails.scheduled_for",
        "pending_emails.sent_at",
        "flows.name",                   # 2
        "flow_steps.subject",           # 3
        "flow_steps.trigger_type",      # 4
        "flow_steps.delay_minutes",     # 5
        "pending_emails.updated_at",    # 6
        "pending_emails.status",        # 7
        "flow_steps.mail_id",       # 8
        "mails.subject",             # 9
        "mails.identifier",          # 10
      ],
      joinargs = [
        (table: "flows", tableAs: "flows", on: @["pending_emails.flow_id = flows.id"]),
        (table: "flow_steps", tableAs: "flow_steps", on: @["pending_emails.flow_step_id = flow_steps.id"]),
        (table: "mails", tableAs: "mails", on: @["pending_emails.mail_id = mails.id"]),
      ],
      where = ["user_id = ?"],
      ), contactID)

    emailClicks = getAllRows(conn, sqlSelect(
      table = "email_clicks",
      select = [
        "email_clicks.clicked_at",
        "email_clicks.link_url",
        "mails.subject",
        "flow_steps.subject",
      ],
      joinargs = [
        (table: "pending_emails", tableAs: "", on: @["email_clicks.pending_email_id = pending_emails.id"]),
        (table: "flow_steps", tableAs: "flow_steps", on: @["pending_emails.flow_step_id = flow_steps.id"]),
        (table: "mails", tableAs: "mails", on: @["pending_emails.mail_id = mails.id"]),
      ],
      where = ["email_clicks.user_id = ?"],
      ), contactID)

    emailOpens = getAllRows(conn, sqlSelect(
      table = "email_opens",
      select = [
        "email_opens.opened_at",
        "mails.subject",
        "flow_steps.subject",
      ],
      joinargs = [
        (table: "pending_emails", tableAs: "", on: @["email_opens.pending_email_id = pending_emails.id"]),
        (table: "flow_steps", tableAs: "flow_steps", on: @["pending_emails.flow_step_id = flow_steps.id"]),
        (table: "mails", tableAs: "mails", on: @["pending_emails.mail_id = mails.id"]),
      ],
      where = ["email_opens.user_id = ?"],
      ), contactID)

    emailBounces = getAllRows(conn, sqlSelect(
      table = "email_bounces",
      select = [
        "bounced_at",
        "bounce_type",
        "bounce_subtype",
        "diagnostic_code"
      ],
      where = ["user_id = ?"],
      ), contactID)

    emailComplaints = getAllRows(conn, sqlSelect(
      table = "email_complaints",
      select = [
        "complained_at",
        "complaint_feedback"
      ],
      where = ["user_id = ?"],
      ), contactID)

  var
    bodyJson = parseJson("[]")
    pendingEmailsJson = parseJson("[]")
    tableJson: OrderedTable[string, JsonNode]

  for pendingEmail in pendingEmails:
    let jItem = %* {
      "type": "pending_email",
      "date": (
        if pendingEmail[1] != "":
          pendingEmail[1]
        elif pendingEmail[0] != "":
          pendingEmail[0]
        elif pendingEmail[7] == "cancelled":
          pendingEmail[6]
        else:
          ""
      ),
      "scheduled_for": pendingEmail[0],
      "sent_at": pendingEmail[1],
      "subject": (if pendingEmail[3] != "": pendingEmail[3] else: pendingEmail[9]),
      "flow_name": pendingEmail[2],
      "trigger_type": (if pendingEmail[10] == "double-opt-in": "double-opt-in" else: pendingEmail[4]),
      "delay_minutes": pendingEmail[5],
      "mail_id": pendingEmail[8],
      "mail_identifier": pendingEmail[10],
    }

    if jItem["date"].getStr() == "":
      pendingEmailsJson.add( jItem )
      continue

    bodyJson.add( jItem )
    tableJson[jItem["date"].getStr()] = jItem

  for emailClick in emailClicks:
    let jItem = %* {
      "type": "email_click",
      "date": emailClick[0],
      "link_url": emailClick[1],
      "subject": (if emailClick[3] != "": emailClick[3] else: emailClick[2]),
    }

    bodyJson.add( jItem )
    tableJson[emailClick[0]] = jItem

  for emailOpen in emailOpens:
    let jItem = %* {
      "type": "email_open",
      "date": emailOpen[0],
      "subject": (if emailOpen[2] != "": emailOpen[2] else: emailOpen[1]),
    }

    bodyJson.add( jItem )
    tableJson[emailOpen[0]] = jItem

  for emailBounce in emailBounces:
    let jItem = %* {
      "type": "email_bounce",
      "date": emailBounce[0],
      "bounced_feedback": emailBounce[1],
      "bounce_subtype": emailBounce[2],
      "diagnostic_code": emailBounce[3],
    }

    bodyJson.add( jItem )
    tableJson[emailBounce[0]] = jItem

  for emailComplaint in emailComplaints:
    let jItem = %* {
      "type": "email_complaint",
      "date": emailComplaint[0],
      "complaint_feedback": emailComplaint[1],
    }

    bodyJson.add( jItem )
    tableJson[emailComplaint[0]] = jItem


  tableJson.sort(system.cmp, order = SortOrder.Descending)

  var newBodyJson = parseJson("[]")
  for value in pendingEmailsJson:
    newBodyJson.add(value)

  for k, value in tableJson:
    newBodyJson.add(value)


  resp Http200, newBodyJson
)


contactsRouter.get("/api/contacts/all",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    limit = (if @"size" == "": 5000 else: @"size".parseInt())
    offset = (if @"page" == "": 0 elif @"page".parseInt() == 1: 0 else: (@"page".parseInt() - 1) * limit)

  var
    contacts: seq[seq[string]]
    contactsCount: int

  pg.withConnection conn:
    contacts = getAllRows(conn, sqlSelect(
      table = "contacts",
      select = [
        "contacts.id",
        "contacts.uuid",
        "contacts.email",
        "contacts.name",
        "contacts.requires_double_opt_in",
        "contacts.double_opt_in",
        "contacts.double_opt_in_data",
        "contacts.bounced_at",
        "contacts.complained_at",
        "to_char(contacts.created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
        "to_char(contacts.updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
        "contacts.status",
        "COUNT(pending_emails.id) FILTER (WHERE pending_emails.status = 'sent') AS sent_emails_count",
        "COUNT(pending_emails.id) FILTER (WHERE pending_emails.status = 'pending') AS pending_emails_count",
        "(SELECT COUNT(*) FROM email_opens WHERE email_opens.user_id = contacts.id) AS email_opens_count",
        "(SELECT COUNT(*) FROM email_clicks WHERE email_clicks.user_id = contacts.id) AS email_clicks_count",
        "(SELECT STRING_AGG(lists.name, ', ') FROM subscriptions JOIN lists ON subscriptions.list_id = lists.id WHERE subscriptions.user_id = contacts.id) AS subscribed_lists",
        "contacts.meta->>'country' AS country",
        "CASE WHEN COUNT(pending_emails.id) FILTER (WHERE pending_emails.status = 'sent') = 0 THEN 0 ELSE (SELECT COUNT(*) FROM email_opens WHERE email_opens.user_id = contacts.id) * 100 / COUNT(pending_emails.id) FILTER (WHERE pending_emails.status = 'sent') END AS opening_rate",
        "contacts.has_unsubscribed",
        "contacts.unsubscribed_at",
        "contacts.unscribed_from_lists"
      ],
      joinargs = [
        (table: "pending_emails", tableAs: "", on: @["contacts.id = pending_emails.user_id"])
      ],
      customSQL = "GROUP BY contacts.id ORDER BY contacts.created_at DESC LIMIT $1 OFFSET $2".format(
        $limit,
        $offset
      )))


    contactsCount = getValue(conn, sqlSelect(
      table = "contacts",
      select = ["COUNT(*)"])).parseInt()


  var bodyJson = parseJson("[]")
  let fakeJson = parseJson("{}")
  for contact in contacts:
    bodyJson.add( %* {
      "id": contact[0],
      "uuid": contact[1],
      "email": contact[2],
      "name": contact[3],
      "requires_double_opt_in": (contact[4] == "t"),
      "double_opt_in": (contact[5] == "t"),
      "double_opt_in_data": (if contact[6] != "": parseJson(contact[6]) else: fakeJson),
      "bounced_at": contact[7].split(".")[0],
      "complained_at": contact[8].split(".")[0],
      "created_at": contact[9].split(".")[0],
      "updated_at": contact[10].split(".")[0],
      "status": contact[11],
      "emails_count_sent": contact[12].parseInt(),
      "emails_count_pending": contact[13].parseInt(),
      "emails_count_open": contact[14].parseInt(),
      "emails_count_clicks": contact[15].parseInt(),
      "subscribed_lists": contact[16],
      "country": contact[17],
      "opening_rate": contact[18].parseInt(),
      "has_unsubscribed": (contact[19] == "t"),
      "unsubscribed_at": contact[20].split(".")[0],
      "unscribed_from_lists": contact[21],
    })

  resp Http200, (
    %* {
      "data": bodyJson,
      "count": contactsCount,
      "size": limit,
      "page": offset,
      "last_page": if contactsCount == 0: 0 elif (contactsCount/limit) < 1.0: 1 else: split($(contactsCount/limit + 1), ".")[0].parseInt()
    }
  )
)



