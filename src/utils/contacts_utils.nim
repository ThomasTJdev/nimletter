


import
  std/[
    algorithm,
    json,
    sequtils,
    strutils,
    tables,
    times
  ]

from std/os import getEnv

import
  mmgeoip,
  sqlbuilder


import
  ../database/database_connection,
  ../email/email_optin,
  ../scheduling/schedule_mail,
  ../utils/list_utils,
  ../utils/validate_data,
  ../webhook/webhook_events

type
  UserStatus = enum
    enabled
    disabled

proc getCountryFromIP(ip: string): string =
  if ip == "":
    return ""

  try:
    let
      geoPath = (
        if getEnv("GEOIP_PATH") != "":
          getEnv("GEOIP_PATH")
        else:
          "/usr/share/GeoIP/GeoIP.dat"
        )

      geo     = GeoIP(geoPath)
    return $geo.country_name_by_addr(ip)

  except:
    return ""


proc createMetaWithCountry*(ip: string): string =
  let country = getCountryFromIP(ip)
  if country == "":
    return "{}"
  return $( %* { "country": country } )


proc mergeContactMeta(ip: string, userMeta: JsonNode = nil): JsonNode =
  result = parseJson(createMetaWithCountry(ip))
  if userMeta != nil:
    for k, v in userMeta.pairs:
      result[k] = v


proc parseContactMetaFromBody(jsonBody: JsonNode): (bool, JsonNode, string) =
  if not jsonBody.hasKey("meta"):
    return (true, nil, "")

  let metaNode = jsonBody["meta"]
  case metaNode.kind
  of JObject:
    if metaNode.len() == 0:
      return (true, nil, "")
    return (true, metaNode, "")
  of JString:
    let metaStr = metaNode.getStr().strip()
    if metaStr.len() == 0:
      return (true, nil, "")
    try:
      let metaJson = parseJson(metaStr)
      if metaJson.kind != JObject:
        return (false, nil, "Invalid meta JSON")
      if metaJson.len() == 0:
        return (true, nil, "")
      return (true, metaJson, "")
    except:
      return (false, nil, "Invalid meta JSON")
  else:
    return (false, nil, "Invalid meta JSON")


proc moveFromPendingToSubscription*(userID: string) =
  # Get pending lists, and then loop and add to subscriptions
  pg.withConnection conn:
    let pendingListsData = getValue(conn, sqlSelect(
        table = "contacts",
        select = ["pending_lists"],
        where = ["id = ?"]
      ), userID)

    if pendingListsData != "":
      let lists = pendingListsData.strip(chars={'{', '}'}).split(",")
      if lists.len() == 0 or lists[0] == "":
        return

      for listID in lists:
        # Skip lists that were soft-deleted while the contact was awaiting
        # double opt-in, so confirming opt-in cannot revive a deleted list.
        if isListDeleted(listID):
          echo "List " & listID & " is deleted - skipping pending subscription for user " & userID
          continue
        try:
          if execAffectedRows(conn, sqlInsert(
              table = "subscriptions",
              data  = [
                "user_id",
                "list_id",
              ]),
              userID, listID
          ) > 0:
            #
            # User subscribed to list, create pending email
            #
            let flowIDs = getValue(conn, sqlSelect(table = "lists", select = ["array_to_string(flow_ids, ',')"], where = ["id = ?"]), listID)
            for flowID in flowIDs.split(","):
              if flowID == "":
                continue
              createPendingEmailFromFlowstep(userID, listID, flowID, 1)
          else:
            echo "Error subscribing user to list: " & listID
        except:
          continue

    # Set pendling_list to NULL
    exec(conn, sqlUpdate(
        table = "contacts",
        data  = [
          "pending_lists = NULL",
          "updated_at = ?"
        ],
        where = ["id = ?"]
      ),
      $now().utc, userID
    )


proc addContactToPendinglist*(userID, listID: string): bool =
  pg.withConnection conn:
    exec(conn, sqlUpdate(
        table = "contacts",
        data  = [
          "pending_lists = array_append(pending_lists, ?)",
          "updated_at",
        ],
        where = ["id = ?"]
      ), listID, $now().utc, userID
    )
  return true


proc isContactOnList*(userID, listID: string): bool =
  pg.withConnection conn:
    result = getValue(conn, sqlSelect(
        table = "subscriptions",
        select = ["id"],
        where = ["user_id = ?", "list_id = ?"]
      ), userID, listID).len() > 0


proc addContactToList*(userID, listID: string, flowStep = 1): bool =
  # Never subscribe to a soft-deleted list; doing so would re-arm its flows and
  # keep generating mail after the list was "deleted".
  if isListDeleted(listID):
    echo "List " & listID & " is deleted - skipping subscription for user " & userID
    return false

  pg.withConnection conn:
    if isContactOnList(userID, listID):
      return true

    if execAffectedRows(conn, sqlInsert(
        table = "subscriptions",
        data  = [
          "user_id",
          "list_id",
        ]),
        userID, listID
    ) > 0:
      let flowIDs = getValue(conn, sqlSelect(table = "lists", select = ["array_to_string(flow_ids, ',')"], where = ["id = ?"]), listID)
      for flowID in flowIDs.split(","):
        if flowID == "":
          continue
        createPendingEmailFromFlowstep(userID, listID, flowID, flowStep)
      result = true
    else:
      result = false

  return result

proc addContactToListBody*(body: string): tuple[success: bool, msg: string, data: JsonNode] =
  var
    userID, listID: string
    flowStep: int

  try:
    let jsonBody = parseJson(body)
    userID  = jsonBody.getOrDefault("userID").getStr().strip()
    listID  = jsonBody.getOrDefault("listID").getStr().strip()
    flowStep = jsonBody.getOrDefault("flowStep").getInt()
  except:
    return (false, "Invalid JSON", nil)

  if flowStep == 0:
    flowStep = 1

  let data = addContactToList(userID, listID, flowStep)
  if not data:
    return (false, "Failed to add contact to list", nil)

  return (true, "", %* {
    "success": true,
    "event": "contact_added_to_list",
    "userID": userID,
    "listID": listID,
    "flowStep": flowStep
  })


proc createContact*(email, name: string, requiresDoubleOptIn: bool, listIDs: seq[string], ip: string = "", meta: JsonNode = nil): tuple[success: bool, id: string, alreadyExists: bool] =

  var
    userID: string
    success: bool
  pg.withConnection conn:
    # Reuse the existing ID so callers can act on the existing contact
    # without needing a second lookup.
    let existingID = getValue(conn, sqlSelect(
        table = "contacts",
        select = ["id"],
        where = ["email = ?"]
    ), email)

    if existingID != "":
      return (false, existingID, true)

    success = true
    userID = $insertID(conn, sqlInsert(
        table = "contacts",
        data  = [
          "email",
          "name",
          "requires_double_opt_in",
          "meta",
          "pending_lists" & (if requiresDoubleOptIn and listIDs.len() > 0: "" else: " = NULL"),
        ]),
        email,
        name,
        $requiresDoubleOptIn,
        $(mergeContactMeta(ip, meta)),
        (
          if requiresDoubleOptIn and listIDs.len() > 0:
            "{" & listIDs.join(",") & "}"
          else:
            ""
        )
      )

  return (success, userID, false)


proc createContactManual*(body: string): tuple[success: bool, msg: string, data: JsonNode] =
  var
    email, name, list: string
    requiresDoubleOptIn: bool
    flowStep: int

  var jsonBody: JsonNode
  try:
    jsonBody = parseJson(body)
  except:
    return (false, "Invalid JSON", nil)

  email     = jsonBody.getOrDefault("email").getStr().toLowerAscii().strip()
  name      = jsonBody.getOrDefault("name").getStr().strip()
  flowStep  = jsonBody.getOrDefault("flow_step").getInt()
  requiresDoubleOptIn = jsonBody.getOrDefault("double_opt_in").getBool() == true
  list      = jsonBody.getOrDefault("list").getStr()

  if flowStep == 0:
    flowStep = 1

  if email.strip() == "" or email.len() > 255 or not email.isValidEmail():
    return (false, "Invalid email", nil)

  if name.len() > 255:
    return (false, "Name too long", nil)

  let (metaOk, userMeta, metaErr) = parseContactMetaFromBody(jsonBody)
  if not metaOk:
    return (false, metaErr, nil)

  let listID =
    if list != "":
      listIDfromIdentifier(list)
    else:
      "1" # => Default list

  let (createSuccess, userID, _) = createContact(email, name, requiresDoubleOptIn, listIDs = @[], meta = userMeta)
  if not createSuccess:
    return (false, "Contact already exists", nil)

  let storedMeta = mergeContactMeta("", userMeta)

  if requiresDoubleOptIn:
    emailOptinSend(email, name, userID)

    if listID != "":
      discard addContactToPendinglist(userID, listID)

  elif listID != "":
    discard addContactToList($userID, listID, flowStep = flowStep)

  let data = %* {
      "success": true,
      "id": userID,
      "double_opt_in": requiresDoubleOptIn,
      "email": email,
      "name": name,
      "list": (if list != "": list else: "default"),
      "meta": storedMeta,
      "event": "contact_created"
    }

  parseWebhookEvent(contact_created, data)

  return (true, "", data)


proc contactExists*(body: string): tuple[success: bool, exists: bool, msg: string, data: JsonNode] =

  var email: string
  try:
    email = parseJson(body)["email"].getStr().toLowerAscii().strip()
  except:
    return (false, false, "Invalid JSON", nil)

  if email == "":
    return (false, false, "Email is required", nil)

  var userID: string
  pg.withConnection conn:
    userID = getValue(conn, sqlSelect(
      table = "contacts",
      select = ["id"],
      where = ["email = ?"]
      ), email)

  return (true, userID != "", "", %* {
    "success": true,
    "exists": userID != "",
    "email": email,
    "event": "contact_exists"
  })



proc contactUpdate*(body: string): tuple[success: bool, msg: string, data: JsonNode] =
  var
    contactID, email, name, meta: string
    status: UserStatus
    requiresDoubleOptIn, doubleOptIn: bool

  try:
    let jsonBody = parseJson(body)

    contactID = jsonBody.getOrDefault("contactID").getStr().strip()
    email     = jsonBody.getOrDefault("email").getStr().toLowerAscii().strip()
    name      = jsonBody.getOrDefault("name").getStr().strip()
    status    = parseEnum[UserStatus](jsonBody.getOrDefault("status").getStr(), disabled)
    meta      = jsonBody.getOrDefault("meta").getStr().strip()
    requiresDoubleOptIn = jsonBody.getOrDefault("double_opt_in").getBool()
    doubleOptIn = jsonBody.getOrDefault("opted_in").getBool()
  except:
    return (false, "Invalid JSON", nil)

  if not contactID.isValidInt() and not email.isValidEmail():
    return (false, "Invalid contact ID / email", nil)

  if email.len() > 255 or not email.isValidEmail():
    return (false, "Invalid email", nil)

  if meta.len() > 0:
    try:
      discard parseJson(meta)
    except:
      return (false, "Invalid meta JSON", nil)

  pg.withConnection conn:
    exec(conn, sqlUpdate(
        table = "contacts",
        data  = [
          "updated_at",
          "email",
          "name",
          "status",
          "requires_double_opt_in",
          "double_opt_in",
          "meta",
        ],
        where = [
          (if contactID != "":
            "id = ?"
          else:
            "email = ?")
        ]
      ),
        $now().utc,
        email, name, $status, $requiresDoubleOptIn, $doubleOptIn, meta,
        (if contactID != "":
          contactID
        else:
          email)
      )

  if status != disabled:
    if not requiresDoubleOptIn or doubleOptIn:
      moveFromPendingToSubscription(contactID)
  else:
    pg.withConnection conn:
      exec(conn, sqlUpdate(
          table = "pending_emails",
          data  = [
            "status = 'cancelled'",
            "scheduled_for = NULL",
            "updated_at = ?"
          ],
          where = ["user_id = ?", "status = 'pending'"]),
        $now().utc, contactID)

  let data = %* {
      "success": true,
      "id": contactID,
      "double_opt_in": requiresDoubleOptIn,
      "opted_in": doubleOptIn,
      "email": email,
      "name": name,
      "status": status,
      "meta": (if meta != "": parseJson(meta) else: parseJson("{}")),
      "event": "contact_updated"
    }

  parseWebhookEvent(contact_updated, data)

  return (true, "", data)


proc contactUpdateMeta*(body: string): tuple[success: bool, msg: string, data: JsonNode] =
  var
    email, meta: string

  try:
    let jsonBody = parseJson(body)

    email = jsonBody.getOrDefault("email").getStr().strip().toLowerAscii()
    meta  = jsonBody.getOrDefault("meta").getStr().strip()
  except:
    return (false, "Invalid JSON", nil)

  if email.len() > 255 or not email.isValidEmail():
    return (false, "Invalid email", nil)

  var metaJson: JsonNode
  if meta.len() > 0:
    try:
      metaJson = parseJson(meta)
    except:
      return (false, "Invalid meta JSON", nil)

  # We are using JSONB field. The users meta should either add or update values.
  # If the key already exists, it will be updated, otherwise it will be added.
  pg.withConnection conn:
    exec(conn, sqlUpdate(
        table = "contacts",
        data  = [
          "meta = meta || ?::jsonb",
          "updated_at",
        ],
        where = ["email = ?"]
      ),
      metaJson, $now().utc, email
    )

  let data = %* {
      "success": true,
      "email": email,
      "meta": metaJson,
      "event": "contact_meta_updated"
    }

  return (true, "", data)



proc contactRemoveFromList*(userID, listID, listType: string): tuple[success: bool, msg: string, data: JsonNode] =
  if not userID.isValidInt():
    return (false, "Invalid user ID", nil)

  if not listID.isValidInt():
    return (false, "Invalid list ID", nil)

  if listType == "pending":
    # Remove int from array pendinglists
    pg.withConnection conn:
      exec(conn, sqlUpdate(
          table = "contacts",
          data  = [
            "pending_lists = array_remove(pending_lists, ?)",
            "updated_at",
          ],
          where = ["id = ?"]
        ),
        listID,
        $now().utc,
        userID
      )

    return (true, "", %* {
      "success": true,
      "event": "contact_removed_from_list",
      "userID": userID,
      "listID": listID,
      "listType": listType
    })

  #
  # Get potential flow, so we can stop pending emails
  #
  pg.withConnection conn:
    let flowIDs = getValue(conn, sqlSelect(
        table = "lists",
        select = ["array_to_string(lists.flow_ids, ',') as flows"],
        where = ["id = ?"]
      ), listID)

    if flowIDs != "":
      for flowID in flowIDs.split(","):
        exec(conn, sqlUpdate(
            table = "pending_emails",
            data  = [
              "status = 'cancelled'",
              "scheduled_for = NULL",
              "updated_at = ?"
            ],
            where = [
              "user_id = ?",
              "flow_id = ?",
              "status = 'pending'"
            ]
          ),
          $now().utc, userID, flowID)

    exec(conn, sqlDelete(
        table = "subscriptions",
        where = ["user_id = ?", "list_id = ?"]),
        userID, listID
      )

  return (true, "", %* {
    "success": true,
    "event": "contact_removed_from_list",
    "userID": userID,
    "listID": listID,
    "listType": listType
  })


proc contactRemoveFromListBody*(body: string): tuple[success: bool, msg: string, data: JsonNode] =
  var
    userID, listID, listType: string

  try:
    let jsonBody = parseJson(body)

    userID  = jsonBody.getOrDefault("userID").getStr().strip()
    listID  = jsonBody.getOrDefault("listID").getStr().strip()
    listType = jsonBody.getOrDefault("listType").getStr().strip()
  except:
    return (false, "Invalid JSON", nil)

  let data = contactRemoveFromList(userID, listID, listType)
  if not data.success:
    return (false, data.msg, nil)

  return (true, "", %* {
    "success": true,
    "event": "contact_removed_from_list",
    "userID": userID,
    "listID": listID,
    "listType": listType
  })

