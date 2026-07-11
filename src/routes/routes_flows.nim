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
  ../utils/auth,
  ../utils/validate_data


var flowsRouter*: Router

# Create a new flow
flowsRouter.post("/api/flows/create",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    name = @"name"
    description = @"description"

  if name.strip() == "":
    resp Http400, "Name is required"

  var flowID: string
  pg.withConnection conn:
    flowID = $insertID(conn, sqlInsert(
        table = "flows",
        data  = [
          "name",
          "description"
        ],
      ), name, description
    )

  resp Http200, (
    %* {
      "id": flowID
    }
  )
)


# Get a flow by ID
flowsRouter.get("/api/flows/get",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    flowID = @"flowID"

  if not flowID.isValidInt():
    resp Http400, "Invalid flow ID"

  var data: seq[string]
  pg.withConnection conn:
    data = getRow(conn, sqlSelect(
        table   = "flows",
        select  = [
          "id",
          "name",
          "to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
          "to_char(updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at"        ],
        where   = ["id = ?"]
      ), flowID)

  if data[0].len == 0:
    resp Http404, "Flow not found"

  resp Http200, (
    %* {
      "id": data[0],
      "name": data[1],
      "created_at": data[2],
      "updated_at": data[3]
    }
  )
)


# Update a flow
flowsRouter.post("/api/flows/update",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    flowID = @"flowID"
    name   = @"name".strip()
    description = @"description"

  if name == "":
    resp Http400, "Name is required"

  pg.withConnection conn:
    exec(conn, sqlUpdate(
        table = "flows",
        data  = [
          "name",
          "description",
          "updated_at = CURRENT_TIMESTAMP"
        ],
        where = ["id = ?"]),
      name, description, flowID
    )

  resp Http200
)


# Delete a flow
flowsRouter.delete("/api/flows/delete",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    flowID = @"flowID"

  pg.withConnection conn:
    # exec(conn, sqlDelete(
    #     table = "flows",
    #     where = ["id = ?"]),
    #   flowID)
    exec(conn, sqlUpdate(
        table = "flows",
        data  = [
          "is_deleted = now()"
        ],
        where = ["id = ?"]),
      flowID)

    # Detach the flow from every list. Otherwise the flow ID lingers in
    # lists.flow_ids and new subscribers would keep triggering step 1 of a
    # "deleted" flow.
    exec(conn, sqlUpdate(
        table = "lists",
        data  = [
          "flow_ids = array_remove(flow_ids, ?)"
        ],
        where = ["flow_ids @> ARRAY[?]::int[]"]),
      flowID, flowID)

    exec(conn, sqlUpdate(
        table = "pending_emails",
        data  = [
          "status = 'cancelled'"
        ],
        where = ["flow_id = ?"]),
      flowID)

  resp Http200
)


flowsRouter.get("/api/flows/all",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  var data: seq[seq[string]]
  pg.withConnection conn:
    data = getAllRows(conn, sqlSelect(
        table   = "flows",
        select  = [
          "flows.id",
          "flows.name",
          "flows.description",
          "to_char(flows.created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
          "to_char(flows.updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
          "(SELECT COUNT(*) FROM pending_emails WHERE pending_emails.flow_id = flows.id AND pending_emails.status = 'sent') as sent_count",
          "(SELECT COUNT(*) FROM pending_emails WHERE pending_emails.flow_id = flows.id AND pending_emails.status = 'pending') as pending_count",
          "(SELECT COUNT(DISTINCT email_opens.pending_email_id) FROM email_opens JOIN pending_emails ON email_opens.pending_email_id = pending_emails.id WHERE pending_emails.flow_id = flows.id) as open_count"
        ],
        where   = ["flows.is_deleted IS NULL"],
        customSQL = "ORDER BY flows.name ASC",
      ))

  var respData = parseJson("[]")
  for row in data:
    let sentCount    = (if row[5] == "": 0 else: row[5].parseInt())
    let pendingCount = (if row[6] == "": 0 else: row[6].parseInt())
    let openCount    = (if row[7] == "": 0 else: row[7].parseInt())
    let openingRate  = toInt(if sentCount > 0: (openCount.float / sentCount.float) * 100 else: 0.0)

    respData.add(
      %* {
        "id": row[0],
        "name": row[1],
        "description": row[2],
        "created_at": row[3],
        "updated_at": row[4],
        "sent_count": sentCount,
        "pending_count": pendingCount,
        "opening_rate": openingRate
      }
    )

  resp Http200, (
    %* {
      "data": respData,
      "count": data.len,
      "last_page": 1
    }
  )
)


# Create a new flow step
flowsRouter.post("/api/flow_steps/create",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    flowID       = @"flowID"
    name         = @"name"
    mailID       = @"mailID"
    delayMinutes = @"delay"
    subject      = @"subject"
    triggerType  = @"trigger"
    scheduledTime = if triggerType == "time": @"scheduledTime" else: ""

  if name.strip() == "":
    resp Http400, "Flow name is required"

  if not mailID.isValidInt():
    resp Http400, "Invalid mail ID"

  if triggerType == "time" and scheduledTime == "":
    resp Http400, "Scheduled time is required"

  pg.withConnection conn:

    let stepNumberRaw = getValue(conn, sqlSelect(
        table  = "flow_steps",
        select = ["max(step_number)"],
        where  = ["flow_id = ?"]
      ), flowID)
    var stepNumber = 1
    if stepNumberRaw.len > 0:
      stepNumber = stepNumberRaw.parseInt() + 1


    var
      queryData = @[
        "flow_id",
        "name",
        "mail_id",
        "step_number",
        "delay_minutes",
        "subject",
        "trigger_type"
      ]
    if triggerType == "time":
      queryData.add("scheduled_time")

    var
      queryArgs = @[
        flowID,
        name,
        mailID,
        $stepNumber,
        delayMinutes,
        subject,
        triggerType
      ]
    if triggerType == "time":
      queryArgs.add(scheduledTime)

    let newStepID = insertID(conn, sqlInsert(
        table = "flow_steps",
        data  = queryData),
        queryArgs
    )


    #
    # When a new step is created, all contacts who has completed (sent) the
    # previous step should be scheduled to mail the new step using
    # the proc `createPendingEmail()`
    #

    if stepNumber > 1:
      let prevStepNumber = stepNumber - 1
      let prevStepID = getValue(conn, sqlSelect(
          table  = "flow_steps",
          select = ["id"],
          where  = ["flow_id = ?", "step_number = ?"]
        ), flowID, prevStepNumber)


      if triggerType == "time":
        # For time-based scheduling, use the scheduled time
        exec(conn, sql("""
          WITH subscription_info AS (
          SELECT s.user_id, s.list_id,
            CASE
              WHEN ?::time < CURRENT_TIME THEN
                (CURRENT_DATE + 1 + ?::time)::timestamp
              ELSE
                (CURRENT_DATE + ?::time)::timestamp
            END as scheduled_time
          FROM subscriptions s
          JOIN lists l ON s.list_id = l.id
          JOIN flow_steps fs ON ARRAY[fs.flow_id] <@ l.flow_ids
          WHERE fs.flow_id = ? AND fs.id = ?
          AND EXISTS (
            -- Ensure user has received and completed the previous step
            SELECT 1 FROM pending_emails pe
            WHERE pe.user_id = s.user_id 
            AND pe.flow_id = ? 
            AND pe.flow_step_id = ?
            AND pe.status = 'sent'
          )
          )
          INSERT INTO pending_emails (user_id, list_id, flow_id, flow_step_id, scheduled_for, manual_subject, mail_id)
          SELECT user_id, list_id, ?, ?, scheduled_time, ?, ?
          FROM subscription_info
        """), scheduledTime, scheduledTime, scheduledTime, flowID, prevStepID, flowID, prevStepID, flowID, newStepID, subject, mailID)
      else:
        # For delay-based scheduling, use the delay minutes
        exec(conn, sql("""
          WITH subscription_info AS (
          SELECT s.user_id, s.list_id, NOW() + (fs.delay_minutes || ' minutes')::INTERVAL AS scheduled_time
          FROM subscriptions s
          JOIN lists l ON s.list_id = l.id
          JOIN flow_steps fs ON ARRAY[fs.flow_id] <@ l.flow_ids
          WHERE fs.flow_id = ? AND fs.id = ?
          AND EXISTS (
            -- Ensure user has received and completed the previous step
            SELECT 1 FROM pending_emails pe
            WHERE pe.user_id = s.user_id 
            AND pe.flow_id = ? 
            AND pe.flow_step_id = ?
            AND pe.status = 'sent'
          )
          )
          INSERT INTO pending_emails (user_id, list_id, flow_id, flow_step_id, scheduled_for, manual_subject, mail_id)
          SELECT user_id, list_id, ?, ?, scheduled_time, ?, ?
          FROM subscription_info
        """), flowID, prevStepID, flowID, prevStepID, flowID, newStepID, subject, mailID)


  resp Http200
)


# Get a flow step by ID
flowsRouter.get("/api/flow_steps/get",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    flowStepID = @"flowStepID"

  var data: seq[string]
  pg.withConnection conn:
    data = getRow(conn, sqlSelect(
        table   = "flow_steps",
        select  = ["id", "flow_id", "mail_id", "step_number", "trigger_type", "delay_minutes", "scheduled_time", "subject", "created_at"],
        where   = ["id = ?"]
      ), flowStepID)

  resp Http200, (
    %* {
      "id": data[0],
      "flow_id": data[1],
      "mail_id": data[2],
      "step_number": data[3],
      "trigger_type": data[4],
      "delay_minutes": data[5],
      "scheduled_time": data[6],
      "subject": data[7],
      "created_at": data[8]
    }
  )
)


# Update a flow step
flowsRouter.post("/api/flow_steps/update",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    flowStepID   = @"flowStepID"
    mailID       = @"mailID"
    delayMinutes = @"delayMinutes"
    subject      = @"subject"
    triggerType  = @"trigger"
    scheduledTime = if triggerType == "time": @"scheduledTime" else: ""

  if not flowStepID.isValidInt():
    resp Http400, "Invalid flow step ID"

  if not mailID.isValidInt():
    resp Http400, "Invalid mail ID"

  if not delayMinutes.isValidInt():
    resp Http400, "Invalid delay minutes"

  var
    queryData = @[
      "mail_id",
      "delay_minutes",
      "subject",
      "trigger_type"
    ]
  if triggerType == "time":
    if scheduledTime == "":
      queryData.add("scheduled_time = NULL")
    else:
      queryData.add("scheduled_time")

  var
    queryArgs = @[
      mailID, delayMinutes, subject, triggerType
    ]
  if triggerType == "time" and scheduledTime.len() > 0:
    queryArgs.add(scheduledTime)

  queryArgs.add(flowStepID)

  pg.withConnection conn:
    exec(conn, sqlUpdate(
        table = "flow_steps",
        data  = queryData,
        where = ["id = ?"]),
    queryArgs)

  resp Http200
)


flowsRouter.post("/api/flow_steps/update/step",
proc(request: Request) =
  ## Changing a step to a lower number (e.g. from 4 to 2) will move all current contacts on step 3 and 4 to step 5.
  ## Changing a step to a higher number (e.g. from 3 to 5) will move all current contacts on step 4 and 5 to step 6 (if any).
  createTFD()
  if not c.loggedIn: resp Http401

  let
    flowStepID   = @"flowStepID"

  if not flowStepID.isValidInt():
    resp Http400, "Invalid flow step ID"

  if not @"newStepNumber".isValidInt():
    resp Http400, "Invalid step number"

  let
    newStepNumber = @"newStepNumber".parseInt()

  pg.withConnection conn:
    let oldStepNumberStr = getValue(conn, sqlSelect(
        table  = "flow_steps",
        select = ["step_number"],
        where  = ["id = ?"]
      ), flowStepID)

    if oldStepNumberStr == "":
      resp Http404, "Flow step not found"

    let oldStepNumber = oldStepNumberStr.parseInt()

    let flowID = getValue(conn, sqlSelect(
        table  = "flow_steps",
        select = ["flow_id"],
        where  = ["id = ?"]
      ), flowStepID)


    var moveUsersToStep = 0


    if newStepNumber < oldStepNumber:
      moveUsersToStep = oldStepNumber + 1

      exec(conn, sqlUpdate(
          table = "flow_steps",
          data  = ["step_number = step_number + 1"],
          where = [
            "flow_id = ?",
            "step_number >= ?",
            "step_number < ?"
          ]),
        flowID, newStepNumber, oldStepNumber
      )
    elif newStepNumber > oldStepNumber:
      moveUsersToStep = newStepNumber + 1

      exec(conn, sqlUpdate(
          table = "flow_steps",
          data  = ["step_number = step_number - 1"],
          where = [
            "flow_id = ?",
            "step_number > ?",
            "step_number <= ?"
          ]),
        flowID, oldStepNumber, newStepNumber
      )

    exec(conn, sqlUpdate(
        table = "flow_steps",
        data  = ["step_number = ?"],
        where = ["id = ?"]),
      newStepNumber, flowStepID
    )


    # var stepsToMove: seq[int]
    # if newStepNumber < oldStepNumber:
    #   for i in countUp(newStepNumber, oldStepNumber):
    #     stepsToMove.add(i)
    # elif newStepNumber > oldStepNumber:
    #   for i in countUp(oldStepNumber, newStepNumber):
    #     stepsToMove.add(i)


    # # exec(conn, sqlUpdate(
    # #     table = "pending_emails",
    # #     data  = ["flow_step_id = (SELECT id FROM flow_steps WHERE flow_id = ? AND step_number = ?)"],
    # #     where = [
    # #       "flow_step_id IN (SELECT id FROM flow_steps WHERE flow_id = ? AND step_number = ANY(?::int[]))",
    # #       "status = 'pending'"
    # #     ]),
    # #   flowID, moveUsersToStep, flowID, "{" & stepsToMove.join(",") & "}"
    # # )
    # exec(conn, sql("""
    # UPDATE pending_emails
    # SET flow_step_id = (SELECT id FROM flow_steps WHERE flow_id = ? AND step_number = ?)
    # WHERE flow_step_id IN (SELECT id FROM flow_steps WHERE flow_id = ? AND step_number = ANY(?::int[]))
    # """), flowID, moveUsersToStep, flowID, "{" & stepsToMove.join(",") & "}")


  resp Http200
)


# Delete a flow step
flowsRouter.delete("/api/flow_steps/delete",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let
    flowStepID = @"flowStepID"

  pg.withConnection conn:
    # Cancel pending emails
    exec(conn, sqlUpdate(
        table = "pending_emails",
        data  = ["status = 'cancelled'", "flow_step_id = NULL"],
        where = [
          "flow_step_id = ?",
          "status = 'pending'"
        ]),
      flowStepID
    )

    let flowID = getValue(conn, sqlSelect(
        table  = "flow_steps",
        select = ["flow_id"],
        where  = ["id = ?"]
      ), flowStepID)

    # Get the step number of the flow step to be deleted
    let stepNumber = getValue(conn, sqlSelect(
        table  = "flow_steps",
        select = ["step_number"],
        where  = ["id = ?"]
      ), flowStepID)

    # Delete the flow step
    exec(conn, sqlDelete(
        table = "flow_steps",
        where = ["id = ?"]),
      flowStepID
    )

    # Update the step numbers of the remaining flow steps
    exec(conn, sqlUpdate(
        table = "flow_steps",
        data  = ["step_number = step_number - 1"],
        where = [
          "flow_id = ?",
          "step_number > ?"
        ]),
      flowID, stepNumber
    )

    # Get new flowID and re-schedule pending emails
    let newFlowData = getRow(conn, sqlSelect(
        table  = "flow_steps",
        select = [
          "id",
          "flow_id",
          "delay_minutes"
        ],
        where  = ["step_number = ?"]
      ), stepNumber)

    let
      newFlowStepID = newFlowData[0]

    if newFlowStepID == "":
      resp Http200

    exec(conn, sql("""
      WITH subscription_info AS (
      SELECT s.user_id, s.list_id, NOW() + (fs.delay_minutes || ' minutes')::INTERVAL AS scheduled_time
      FROM subscriptions s
      JOIN lists l ON s.list_id = l.id
      JOIN flow_steps fs ON ARRAY[fs.flow_id] <@ l.flow_ids
      WHERE fs.flow_id = ? AND fs.id = ?
      )
      INSERT INTO pending_emails (user_id, list_id, flow_id, flow_step_id, scheduled_for)
      SELECT user_id, list_id, ?, ?, scheduled_time
      FROM subscription_info
    """), flowID, newFlowStepID, flowID, newFlowStepID)

  resp Http200
)


flowsRouter.get("/api/flow_steps/all",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let flowID = @"flowID".strip()
  if not flowID.isValidInt():
    resp Http400, "Invalid flow ID"

  var data: seq[seq[string]]
  pg.withConnection conn:
    data = getAllRows(conn, sqlSelect(
        table   = "flow_steps",
        select  = [
          "flow_steps.id",
          "flow_steps.flow_id",
          "flow_steps.mail_id",
          "flow_steps.step_number",
          "flow_steps.trigger_type",
          "flow_steps.delay_minutes",
          "flow_steps.name",
          "flow_steps.subject",
          "to_char(flow_steps.created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at",
          "to_char(flow_steps.updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at",
          "mails.name",
          "(SELECT COUNT(*) FROM pending_emails WHERE pending_emails.flow_step_id = flow_steps.id AND pending_emails.status = 'pending') as pending_count",
          "(SELECT COUNT(*) FROM pending_emails WHERE pending_emails.flow_step_id = flow_steps.id AND pending_emails.status = 'sent') as sent_count",
          "flow_steps.scheduled_time"
        ],
        joinargs = [
          (table: "mails", tableAs: "", on: @["mails.id = flow_steps.mail_id"])
        ],
        where = [
          "flow_steps.flow_id = ?"
        ],
        customSQL = "ORDER BY flow_steps.step_number ASC"
        ), flowID)


  var respData = parseJson("[]")
  for row in data:
    respData.add(
      %* {
        "id": row[0],
        "flow_id": row[1],
        "mail_id": row[2],
        "step_number": row[3],
        "trigger_type": row[4],
        "delay_minutes": row[5],
        "name": row[6],
        "subject": row[7],
        "created_at": row[8],
        "updated_at": row[9],
        "mail_name": row[10],
        "pending_count": (if row[11] == "": 0 else: row[11].parseInt()),
        "sent_count": (if row[12] == "": 0 else: row[12].parseInt()),
        "scheduled_time": row[13]
      }
    )

  resp Http200, respData
)


flowsRouter.get("/api/flow_steps/stats/contacts",
proc(request: Request) =
  createTFD()
  if not c.loggedIn: resp Http401

  let flowStepID = @"flowStepID"

  if not flowStepID.isValidInt():
    resp Http400, "Invalid flow step ID"

  var data: seq[seq[string]]
  pg.withConnection conn:
    data = getAllRows(conn, sqlSelect(
        table   = "pending_emails",
        select  = [
          "pending_emails.user_id",
          "pending_emails.status",
          "to_char(pending_emails.scheduled_for, 'YYYY-MM-DD HH24:MI:SS') as scheduled_for",
          "to_char(pending_emails.sent_at, 'YYYY-MM-DD HH24:MI:SS') as sent_at",
          "contacts.email"
          ],
          joinargs = [
            (table: "contacts", tableAs: "", on: @["contacts.id = pending_emails.user_id"])
          ],
          where   = ["pending_emails.flow_step_id = ?"],
          customSQL = "GROUP BY pending_emails.user_id, pending_emails.status, pending_emails.scheduled_for, pending_emails.sent_at, contacts.email, pending_emails.id ORDER BY pending_emails.scheduled_for DESC"
          ), flowStepID)

  var respData = parseJson("[]")
  for row in data:
    respData.add(
      %* {
      "user_id": row[0],
      "user_email": row[4],
      "status": row[1],
      "scheduled_for": row[2],
      "sent_at": row[3],
      }
    )

  resp Http200, (
    %* {
        "data": respData,
        "last_page": 1
        }
    )
)
