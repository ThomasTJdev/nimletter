


import
  std/[
    json,
    strutils
  ]


import
  mummy, mummy/routers,
  mummy_utils


import
  sqlbuilder


import
  ../database/database_connection,
  ../scheduling/schedule_mail,
  ../utils/auth,
  ../utils/contacts_utils,
  ../utils/validate_data


var listsRouter*: Router

listsRouter.post("/api/lists/create",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    name    = @"name"
    identifier = (if @"identifier" == "": name.toLowerAscii().replace(" ", "-").subStr(0, 100).strip(chars={'-', '_'}) else: @"identifier".replace(" ", "-").subStr(0, 100).strip(chars={'-', '_'}))
    description = @"description"
    flowIDRaw   = @"flowID"
    requireOptIn = @"requireOptIn" == "true"

  if name.strip() == "":
    resp Http400, "Name is required"

  #
  # Validate flow ID
  #
  var flowID: string
  if flowIDRaw != "":
    pg.withConnection conn:
      flowID = getValue(conn, sqlSelect(
          table   = "flows",
          select  = ["id"],
          where   = ["id = ?"]
        ), flowIDRaw)

    if flowID == "":
      resp Http400, "Flow ID not found, ID: " & flowIDRaw


  #
  # Insert into database
  #
  if flowID == "":
    pg.withConnection conn:
      exec(conn, sqlInsert(
          table = "lists",
          data  = [
            "name",
            "identifier",
            "require_optin",
            "description",
          ]),
          name,
          identifier,
          $requireOptIn,
          description
        )

  else:
    pg.withConnection conn:
      exec(conn, sqlInsert(
          table = "lists",
          data  = [
            "name",
            "identifier",
            "require_optin",
            "description",
            "flow_id",
          ]),
          name,
          identifier,
          $requireOptIn,
          description,
          flowID
        )


  resp Http200
)


listsRouter.get("/api/lists/get",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  #
  # Validate input
  #
  let
    listID = @"listID"

  if not listID.isValidInt():
    resp Http400, "Invalid UUID"

  #
  # Get data
  #
  var data: seq[string]
  var flows: seq[seq[string]]
  pg.withConnection conn:
    data = getRow(conn, sqlSelect(
        table   = "lists",
        select  = ["lists.name", "lists.identifier", "lists.description", "array_to_string(lists.flow_ids, ',') as flows", "lists.uuid", "lists.require_optin"],
        where   = ["lists.id = ?"]
      ), listID)

    flows = getAllRows(conn, sqlSelect(
        table   = "flows",
        select  = ["id", "name"],
        where   = ["id = ANY(?::int[])"]
      ), "{" & data[3] & "}")

  var flowdata = parseJson("[]")
  for row in flows:
    flowdata.add(%* {
      "id": row[0],
      "name": row[1]
    })

  resp Http200, (
    %* {
      "name": data[0],
      "identifier": data[1],
      "description": data[2],
      "uuid": data[4],
      "flow_id": flowdata,
      "require_optin": data[5] == "t"
    }
  )
)


listsRouter.post("/api/lists/update",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    listID   = @"listID"
    name     = @"name"
    identifier  = (if @"identifier" == "": name.toLowerAscii().replace(" ", "-").subStr(0, 100).strip(chars={'-', '_'}) else: @"identifier".replace(" ", "-").subStr(0, 100).strip(chars={'-', '_'}))
    description = @"description"
    requireOptIn = @"requireOptIn" == "true"

  #
  # Validate input
  #
  if not listID.isValidInt():
    resp Http400, "Invalid ID"

  #
  # Simple update
  #
  else:
    pg.withConnection conn:
      exec(conn, sqlUpdate(
          table = "lists",
          data  = [
            "name",
            "identifier",
            "description",
            "require_optin"
          ],
          where = ["id = ?", "identifier != 'default'"]),
        name, identifier, description, $requireOptIn, listID)

  resp Http200
)


listsRouter.post("/api/lists/flow/@action",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    listID = @"listID"
    flowIDRaw = @"flowID"
    action = @"action"

  if action notin ["add", "remove"]:
    resp Http400, "Invalid action"

  if not flowIDRaw.isValidInt():
    resp Http400, "Invalid flow ID"

  if action == "remove":
    pg.withConnection conn:
      exec(conn, sqlUpdate(
          table = "lists",
          data  = [
            "flow_ids = array_remove(flow_ids, ?)"
          ],
          where = ["id = ?"]),
        flowIDRaw, listID
      )

  else:
    #
    # Validate flow ID
    #
    var flowID: string
    pg.withConnection conn:
      flowID = getValue(conn, sqlSelect(
          table   = "flows",
          select  = ["id"],
          where   = ["id = ?"]
        ), flowIDRaw)

    if flowID == "":
      resp Http400, "Flow ID not found, ID: " & flowIDRaw

    #
    # Check if flow is already in list
    #
    var flowInList: bool
    pg.withConnection conn:
      flowInList = getValue(conn, sqlSelect(
          table   = "lists",
          select  = ["id"],
          where   = ["id = ?", "flow_ids @> ARRAY[?]::int[]"]), listID, flowID).len() > 0

    if flowInList:
      resp Http400, "Flow already in list"

    #
    # Add flow to list
    #
    var users: seq[seq[string]]
    pg.withConnection conn:
      exec(conn, sqlUpdate(
          table = "lists",
          data  = [
            "flow_ids = array_append(flow_ids, ?)"
          ],
          where = ["id = ?"]),
        flowID, listID
      )

      users = getAllRows(conn, sqlSelect(
          table   = "subscriptions",
          select  = ["subscriptions.user_id"],
          joinargs = [
            (table: "contacts", tableAs: "", on: @["contacts.id = subscriptions.user_id"])
          ],
          where   = ["subscriptions.list_id = ?", "contacts.status = 'enabled'"]
        ), listID)

    for user in users:
      createPendingEmailFromFlowstep(user[0], listID, flowID, 1)

  resp Http200
)




listsRouter.delete("/api/lists/delete",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  #
  # Validate input
  #
  let
    listID = @"listID"

  if not listID.isValidInt():
    resp Http400, "Invalid ID"

  #
  # Delete
  #
  pg.withConnection conn:
    # exec(conn, sqlDelete(
    #     table = "lists",
    #     where = ["id = ?", "identifier != 'default'"]),
    #   listID)
    exec(conn, sqlUpdate(
        table = "lists",
        data  = [
          "is_deleted = now()"
        ],
        where = ["id = ?"]),
      listID)

    exec(conn, sqlUpdate(
        table = "pending_emails",
        data  = [
          "status = 'cancelled'"
        ],
        where = ["list_id = ?"]),
      listID)

  resp Http200
)


listsRouter.get("/api/lists/all",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  var
    lists: seq[seq[string]]
    listsCount: int
  pg.withConnection conn:
    lists = getAllRows(conn, sqlSelect(
        table   = "lists",
        select  = [
          "lists.id",
          "lists.uuid",
          "lists.name",
          "lists.identifier",
          "lists.description",
          "array_to_string(lists.flow_ids, ',') as flows",
          "to_char(lists.created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
          "to_char(lists.updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
          "(SELECT COUNT(*) FROM subscriptions WHERE subscriptions.list_id = lists.id) as user_count",
          "lists.require_optin"
        ],
        where   = ["lists.is_deleted IS NULL"],
        customSQL = "ORDER BY lists.name ASC",
      ))

    listsCount = getValue(conn, sqlSelect(
        table = "lists",
        select = ["COUNT(*)"],
        where   = ["lists.is_deleted IS NULL"]
      )).parseInt()


  var bodyJson = parseJson("[]")
  for row in lists:
    bodyJson.add(%* {
      "id": row[0],
      "uuid": row[1],
      "name": row[2],
      "identifier": row[3],
      "description": row[4],
      "flows": row[5],
      "created_at": row[6],
      "updated_at": row[7],
      "user_count": row[8],
      "require_optin": row[9] == "t"
    })

  resp Http200, (
    %* {
      "data": bodyJson,
      "count": listsCount,
      "last_page": 1
    }
  )
)


listsRouter.post("/api/lists/users/add",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  var
    listID: string
    usersText: string
    jsonBody: JsonNode

  try:
    jsonBody = parseJson(request.body)
    # Handle listID as either string or number
    let listIDNode = jsonBody.getOrDefault("listID")
    if listIDNode.kind == JString:
      listID = listIDNode.getStr().strip()
    elif listIDNode.kind == JInt:
      listID = $listIDNode.getInt()
    else:
      resp Http400, "Invalid list ID format"

    usersText = jsonBody.getOrDefault("users").getStr()
  except:
    resp Http400, "Invalid JSON"

  if not listID.isValidInt():
    resp Http400, "Invalid list ID"

  if usersText.strip() == "":
    resp Http400, "No users provided"

  #
  # Parse users from text - support tab, comma, or space separated
  #
  var users: seq[tuple[email: string, name: string]] = @[]
  var errors: seq[string] = @[]
  var added: int = 0

  for line in usersText.splitLines():
    let trimmed = line.strip()
    if trimmed == "":
      continue

    var email, name: string
    var found = false

    # Try tab-separated first
    if '\t' in trimmed:
      let parts = trimmed.split('\t', maxsplit = 1)
      if parts.len() >= 2:
        email = parts[0].strip()
        name = parts[1].strip()
        found = true
    # Try comma-separated
    elif ',' in trimmed:
      let parts = trimmed.split(',', maxsplit = 1)
      if parts.len() >= 2:
        email = parts[0].strip()
        name = parts[1].strip()
        found = true
    # Try space-separated (last resort)
    else:
      let parts = trimmed.splitWhitespace(maxsplit = 1)
      if parts.len() >= 2:
        email = parts[0].strip()
        name = parts[1].strip()
        found = true

    if not found:
      errors.add("Invalid format: " & trimmed)
      continue

    email = email.toLowerAscii().strip()
    name = name.strip()

    if email == "" or not email.isValidEmail():
      errors.add("Invalid email: " & email)
      continue

    if name == "":
      errors.add("Missing name for: " & email)
      continue

    if name.len() > 255:
      errors.add("Name too long for: " & email)
      continue

    users.add((email: email, name: name))

  if users.len() == 0:
    resp Http400, "No valid users found"

  #
  # Add users to list
  #
  pg.withConnection conn:
    for user in users:
      var userID: string

      # Check if contact exists
      userID = getValue(conn, sqlSelect(
          table = "contacts",
          select = ["id"],
          where = ["email = ?"]
        ), user.email)

      # Create contact if it doesn't exist
      if userID == "":
        let meta = createMetaWithCountry(request.ip)
        userID = $insertID(conn, sqlInsert(
            table = "contacts",
            data  = [
              "email",
              "name",
              "requires_double_opt_in",
              "meta",
            ]),
            user.email,
            user.name,
            "false",
            meta
          )

      # Add to list (if not already on list)
      if not isContactOnList(userID, listID):
        if addContactToList(userID, listID):
          added += 1
        else:
          errors.add("Failed to add " & user.email & " to list")
      else:
        # User already on list, but we'll count it as success
        added += 1

  resp Http200, (
    %* {
      "success": true,
      "added": added,
      "total": users.len(),
      "errors": errors
    }
  )
)
