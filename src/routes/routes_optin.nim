


import
  std/[
    json,
    options,
    sequtils,
    strutils,
    tables,
    times
  ]

from std/os import getEnv

import
  mummy, mummy/routers,
  mummy_utils


import
  sqlbuilder


import
  ../database/database_connection,
  ../email/email_optin,
  ../utils/contacts_utils,
  ../utils/list_utils,
  ../utils/google_recaptcha,
  ../utils/validate_data,
  ../webhook/webhook_events

from ../utils/contacts_utils import createMetaWithCountry, contactRemoveFromList


include
  "../html/optin.nimf"




const requiresDoubleOptIn = true

var optinRouter*: Router


optinRouter.get("/subscribe",
proc(request: Request) =
  if getEnv("ALLOW_GLOBAL_SUBSCRIPTION").toLowerAscii() != "true":
    resp Http200, nimfOptinSubscribe(false, "Please find a subscription list first", "", listUUID = "")

  var defaultListUUID: string
  pg.withConnection conn:
    defaultListUUID = getValue(conn, sqlSelect(
        table = "lists",
        select = ["uuid"],
        where = ["identifier = 'default'"]
      ))
  redirect("/subscribe/" & defaultListUUID)
)


optinRouter.get("/subscribe/optin",
proc(request: Request) =
  let userUUID = @"contactUUID"

  if not userUUID.isValidUUID():
    resp Http200, nimfOptinSubscribeOptin("")

  # Don't allow user-agents that are not browsers
  elif not request.headers.hasKey("User-Agent") or request.headers["User-Agent"] == "":
    resp Http204

  var
    userID: string
    name: string
    email: string

  let meta = createMetaWithCountry(request.ip)


  pg.withConnection conn:
    let userData = getRow(conn, sqlSelect(table = "contacts", select = ["id", "name", "email"], where = ["uuid = ?"]), userUUID)

    userID  = userData[0]
    name    = userData[1]
    email   = userData[2]

    if userID == "":
      resp Http200, nimfOptinSubscribe(true, "We could not find your email.. subscribe again.", "")

    exec(conn, sqlUpdate(
        table = "contacts",
        data  = [
          "double_opt_in",
          "double_opt_in_data",
          "meta"
        ],
        where = ["uuid = ?"]),
        "true",
        $(
          %* {
            "ua": $request.headers["User-Agent"],
            "ip": $request.ip,
            "time": $(now().utc).format("yyyy-MM-dd HH:mm:ss")
          }
        ),
        meta,
        userUUID
      )

  moveFromPendingToSubscription(userID)

  let data = %* {
      "success": true,
      "id": userID,
      "name": name,
      "email": email,
      "event": "contact_optedin"
    }

  parseWebhookEvent(contact_optedin, data)

  resp Http200, nimfOptinSubscribeOptin(userUUID)
)


optinRouter.get("/subscribe/@listUUID",
proc(request: Request) =
  resp Http200, nimfOptinSubscribe(true, "", "", listUUID = @"listUUID")
)


optinRouter.post("/subscribe/@lists",
proc(request: Request) =

  let
    email = @"email"
    name  = @"name"
    lists = @"lists".split(",")

  if @"username_second" != "":
    resp Http200, nimfOptinSubscribe(true, "", "")

  if not email.isValidEmail():
    resp Http400, nimfOptinSubscribe(true, "Invalid email", "")

  #when not defined(dev):
  if not checkReCaptcha(@"g-recaptcha-response", request.ip):
    resp Http400, nimfOptinSubscribe(true, "Invalid captcha", "")


  var
    userID: string
    createSuccess: bool
    listsData: tuple[requireOptIn: bool, ids: seq[string]] = (true, @["1"])
  pg.withConnection conn:

    #
    # If we have any pending lists, then get those
    #
    if lists.len() > 0:
      var listsTmp: seq[string]
      for listUUID in lists:
        if not listUUID.isValidUUID():
          continue
        listsTmp.add(listUUID)
      listsData = listIDsFromUUIDs(listsTmp, true)

    (createSuccess, userID) = createContact(email, name, listsData.requireOptIn, listsData.ids, request.ip)

  if not createSuccess:
    # Do not show if success or not since that would allow a user to check
    # if the contact already exists.
    resp Http200, nimfOptinSubscribe(false, "", "Success")

  if listsData.requireOptIn:
    emailOptinSend(email, name, userID)
  else:
    for listID in listsData.ids:
      discard addContactToList(userID, listID)

  let data = %* {
      "success": true,
      "id": userID,
      "double_opt_in": listsData.requireOptIn,
      "listIDs": listsData.ids,
      "email": email,
      "name": name,
      "event": "contact_created"
    }

  parseWebhookEvent(contact_created, data)

  resp Http200, nimfOptinSubscribe(false, "", "Success")
)

optinRouter.get("/unsubscribe",
proc(request: Request) =
  let userUUID = @"contactUUID"

  if not userUUID.isValidUUID():
    resp Http200, nimfOptinUnubscribe("", "", "")

  let unsubscribeFromAll = @"unsubscribeFromAll" == "true"


  # For streamlining the code
  var listID: string
  var listIdentifier: string
  var listUUID: string

  # Used in callback event
  var listUUIDs: seq[string]
  var listIdentifiers: seq[string]

  var onlyOneList: bool = false
  var userData: seq[string]

  pg.withConnection conn:

    # First get user info
    userData = getRow(conn, sqlSelect(table = "contacts", select = ["id", "name", "email"], where = ["uuid = ?"]), userUUID)

    # Guard early: unknown UUID means there is nothing to unsubscribe from
    if userData[0] == "":
      resp Http200, nimfOptinUnubscribe("", "", "", unsubscribeFromAll)

    if not unsubscribeFromAll:
      # Now get listID from latest email from pending_emails
      let lastEmailListID = getValue(conn, sqlSelect(table = "pending_emails", select = ["list_id"], where = ["user_id = ?"], customSQL = "ORDER BY created_at DESC LIMIT 1"), userData[0])
      if lastEmailListID != "":
        listID = lastEmailListID
        let listData = getRow(conn, sqlSelect(table = "lists", select = ["id", "identifier", "uuid"], where = ["id = ?"]), listID)
        listUUID = listData[2]
        listIdentifier = listData[1]

    else:
      exec(conn, sqlUpdate(
        table = "contacts",
        data  = [
          "double_opt_in",
          "double_opt_in_data",
        ],
        where = ["uuid = ?"]
        ), "false", "", userUUID)


    #
    # Remove from lists
    #
    if not unsubscribeFromAll:
      listUUIDs.add(listUUID)
      listIdentifiers.add(listIdentifier)
      discard contactRemoveFromList(userData[0], listID, "list")
    else:
      let listIds = getAllRows(conn, sqlSelect(table = "subscriptions", select = ["list_id"], where = ["user_id = ?"]), userData[0])
      var tmpListIDs: seq[string]
      for listId in listIds:
        tmpListIDs.add(listId[0])
        discard contactRemoveFromList(userData[0], listId[0], "list")

      # Get data to event hook
      if tmpListIDs.len() > 0:
        let listData = getAllRows(conn, sqlSelect(table = "lists", select = ["uuid", "identifier"], where = ["id = ANY(?::int[])"]), "{" & tmpListIDs.join(",") & "}")
        for listId in listData:
          listUUIDs.add(listId[0])
          listIdentifiers.add(listId[1])

  pg.withConnection conn:
    exec(conn, sqlUpdate(
      table = "contacts",
      data  = [
        "has_unsubscribed",
        "unsubscribed_at",
        "unscribed_from_lists"
      ],
      where = ["uuid = ?"]
      ), "true", $(now().utc).format("yyyy-MM-dd HH:mm:ss"), listIdentifiers.join(","), userUUID)

  let data = %* {
      "success": true,
      "id": userData[0],
      "name": userData[1],
      "email": userData[2],
      "listUUIDs": listUUIDs,
      "listIdentifiers": listIdentifiers,
      "event": "contact_optedin"
    }

  parseWebhookEvent(contact_unsubscribed, data)

  resp Http200, nimfOptinUnubscribe(userUUID, userData[1], userData[2], unsubscribeFromAll)
)


