import
  std/[
    strutils,
    times
  ]

import
  sqlbuilder

import
  ../database/database_connection,
  ../database/database_queries



proc triggerScheduleEmail*(pendingEmail: PendingMail) =
  when defined(dev):
    echo "Triggering email with ID " & pendingEmail.id

  let scheduledFor = now().utc + (
    if pendingEmail.triggerDelay == 0:
      1.minutes
    else:
      pendingEmail.triggerDelay.minutes
    )

  pg.withConnection conn:
    exec(conn, sqlUpdate(
      table = "pending_emails",
      data  = [
        "scheduled_for",
        "updated_at"
      ],
      where = [
        "id = ?",
        "scheduled_for IS NULL",
        "status = 'pending'"
      ]),
        scheduledFor,
        $(now().utc).format("yyyy-MM-dd HH:mm:ss"),
        pendingEmail.id
    )


proc createPendingEmail*(
  userID, listID, flowID, flowStepID, mailID: string,
  triggerType: string = "delay",
  scheduledFor: DateTime = now().utc,
  status: string = "pending",
  manualSubject: string = "",
  scheduledTime: string = "",
) =

  var scheduledForFormatted: string
  if triggerType == "delay":
    scheduledForFormatted = $scheduledFor.format("yyyy-MM-dd HH:mm:ss")
  elif triggerType == "immediate":
    scheduledForFormatted = $(now().utc).format("yyyy-MM-dd HH:mm:ss")
  elif triggerType == "time":
    if scheduledTime != "":
      # Combine current date with the scheduled time
      let today = now().utc
      let timeParts = scheduledTime.split(":")
      let scheduledDateTime = dateTime( today.year, today.month, today.monthday, parseInt(timeParts[0]), parseInt(timeParts[1]), 0, zone = utc() )

      # If the time has already passed today, schedule for tomorrow
      if scheduledDateTime < now().utc:
        scheduledForFormatted = $(scheduledDateTime + 1.days).format("yyyy-MM-dd HH:mm:ss")
      else:
        scheduledForFormatted = $scheduledDateTime.format("yyyy-MM-dd HH:mm:ss")
    else:
      scheduledForFormatted = $(now().utc).format("yyyy-MM-dd HH:mm:ss")
  else:
    scheduledForFormatted = "NULL"

  echo "Scheduled for " & scheduledForFormatted & " for user " & userID

  var args = @[userID]
  var data = @["user_id"]
  if listID != "":
    data.add("list_id")
    args.add(listID)
  if flowID != "":
    data.add("flow_id")
    args.add(flowID)
  if flowStepID != "":
    data.add("flow_step_id")
    args.add(flowStepID)
  if mailID != "":
    data.add("mail_id")
    args.add(mailID)
  if triggerType != "":
    data.add("trigger_type")
    args.add(triggerType)
  if status != "":
    data.add("status")
    args.add(status)
  if scheduledForFormatted != "NULL":
    data.add("scheduled_for")
    args.add(scheduledForFormatted)
  if manualSubject != "":
    data.add("manual_subject")
    args.add(manualSubject)

  pg.withConnection conn:
    # Check if the user already has a pending email for this flow and step
    if flowID.len() > 0 and flowStepID.len() > 0:
      if getValue(conn, sqlSelect(
        table = "pending_emails",
        select = ["id"],
        where = ["user_id = ?", "flow_id = ?", "flow_step_id = ?"]
      ), userID, flowID, flowStepID) != "":
        echo "User already has a pending email for this flow and step"
        return

    exec(conn, sqlInsert(
      table = "pending_emails",
      data  = data,
    ), args)


proc createPendingEmailFromFlowstep*(userID, listID, flowID: string, stepNumber: int) =

  echo "Creating pending email from flowID " & flowID & " and step " & $stepNumber & " for user " & userID

  # Guard against soft-deleted flows. A flow is never hard-deleted; it is only
  # marked via flows.is_deleted. Without this check, deleted flows keep being
  # re-queued through every enqueue path that funnels here (new subscriptions,
  # post-send step chaining, open/click triggers, list re-attach), so mails
  # keep appearing even after the flow was "deleted".
  pg.withConnection conn:
    if getValue(conn, sqlSelect(
      table  = "flows",
      select = ["id"],
      where  = ["id = ?", "is_deleted IS NULL"]
    ), flowID) == "":
      return

  var flowStep: seq[string]
  pg.withConnection conn:
    flowStep = getRow(conn, sqlSelect(
      table   = "flow_steps",
      select  = @[
        "id",
        "mail_id",
        "step_number",
        "trigger_type",
        "delay_minutes",
        "subject",
        "scheduled_time"
      ],
      where = [
        "flow_id = ?",
        "step_number = ?"
      ]
    ), flowID, stepNumber)

  if flowStep[0] == "":
    return

  createPendingEmail(
    userID = userID,
    listID = listID,
    flowID = flowID,
    flowStepID = flowStep[0],
    mailID = flowStep[1],
    triggerType = flowStep[3],
    scheduledFor = (now().utc + parseInt(flowStep[4]).minutes),
    status = "pending",
    manualSubject = flowStep[5],
    scheduledTime = flowStep[6]
  )


proc createPendingEmailToAllListContacts*(listID, mailID: string): tuple[success: bool, msg: string] =
  ## Fan-out a list send into pending_emails in one SQL statement.
  ## The previous per-contact SELECT+INSERT loop did ~2 DB round-trips per
  ## subscriber on the HTTP thread and caused proxy 504s around ~8k users.

  # Check if the email is archived before creating pending emails
  pg.withConnection conn:
    let mailCategory = getValue(conn, sqlSelect(
      table = "mails",
      select = ["category"],
      where = ["id = ?"]
    ), mailID)

    if mailCategory == "archived":
      echo "Email with mailID " & mailID & " is archived - skipping creation of pending emails"
      return (false, "Email with mailID " & mailID & " is archived - skipping creation of pending emails")

    # Bulk insert: one row per subscriber, honouring mails.send_once the same
    # way the old loop did (skip users who already have a row for this mail
    # when send_once is true). Contacts with a hard bounce or spam complaint
    # on record are skipped to protect sender reputation. Delivery still
    # happens via the scheduler + mailChannel; this only enqueues.
    let scheduledFor = $(now().utc).format("yyyy-MM-dd HH:mm:ss")
    let inserted = execAffectedRows(conn, sql("""
      INSERT INTO pending_emails (
        user_id, list_id, mail_id, trigger_type, status, scheduled_for
      )
      SELECT
        s.user_id,
        ?,
        ?,
        'immediate',
        'pending',
        ?
      FROM subscriptions s
      JOIN contacts c ON c.id = s.user_id
      WHERE s.list_id = ?
        AND c.bounced_at IS NULL
        AND c.complained_at IS NULL
        AND NOT EXISTS (
          SELECT 1
          FROM pending_emails pe
          JOIN mails m ON pe.mail_id = m.id
          WHERE pe.user_id = s.user_id
            AND pe.mail_id = ?
            AND m.send_once = true
        )
    """), listID, mailID, scheduledFor, listID, mailID)

    echo "Created " & $inserted & " pending emails for list " & listID & " mail " & mailID
    return (true, "Pending emails created for all contacts on list " & listID)