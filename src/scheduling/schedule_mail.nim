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
    echo "Flow end reached"
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

  var contacts: seq[seq[string]]
  pg.withConnection conn:
    contacts = getAllRows(conn, sqlSelect(
      table = "subscriptions",
      select = ["user_id"],
      where = ["list_id = ?"]
    ), listID)

  for contact in contacts:
    # Check the send_once flag
    pg.withConnection conn:
      if getValue(conn, sqlSelect(
        table = "pending_emails",
        select = ["pending_emails.id"],
        joinargs = [
          (table: "mails", tableAs: "", on: @["pending_emails.mail_id = mails.id"])
        ],
        where = [
          "pending_emails.user_id = ?",
          "pending_emails.mail_id = ?",
          "mails.send_once = true"
        ],
        customSQL = "LIMIT 1"
      ), contact[0], mailID) != "":
        echo "User " & contact[0] & " has already received this email"
        continue

    # Create the pending email
    createPendingEmail(
      userID = contact[0],
      listID = listID,
      flowID = "",
      flowStepID = "",
      mailID = mailID,
      triggerType = "immediate",
      status = "pending"
    )
  return (true, "Pending emails created for all contacts on list " & listID)