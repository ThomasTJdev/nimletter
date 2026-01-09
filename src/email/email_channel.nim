
import
  std/[
    os,
    strutils,
    times
  ]

import
  sqlbuilder

import
  ../database/database_connection,
  ../database/database_queries,
  ../email/email_connection,
  ../scheduling/schedule_mail


type
  PendingMailObj* = object
    id*: string
    uuid*: string
    userID*: string
    listID*: string
    flowID*: string
    flowStepID*: string
    triggerType*: string
    scheduledFor*: string
    status*: string
    messageID*: string
    createdAt*: string
    updatedAt*: string
    mailID*: string
    manualHTML*: string
    manualSubject*: string
    mailCategory*: string  # Category of the mail (e.g., "archived") - populated when fetching pending emails

var
  mailChannel*: Channel[PendingMailObj]
  mailThread*: Thread[void]

proc scheduleNextFlowStep(pendingEmail: PendingMailObj, stepNumber: string) =
  createPendingEmailFromFlowstep(
    pendingEmail.userID, pendingEmail.listID, pendingEmail.flowID,
    (parseInt(stepNumber) + 1)
  )


proc getUserData(userID: string): seq[string] =
  pg.withConnection conn:
    return getRow(conn, sqlSelect(
      table = "contacts",
      select = [
        "id",
        "email",
        "name"
      ],
      where = [
        "id = ?"
      ]
    ), userID)



proc getMailData(flowStepID: string): string =
  pg.withConnection conn:
    result = getValue(conn, sqlSelect(
      table = "flow_steps",
      select = [
        "flow_steps.step_number",
      ],
      where = [
        "flow_steps.id = ?"
      ]
    ), flowStepID)



proc sendPendingEmail(pendingEmail: PendingMailObj) =
  # Fetch user and email details
  echo "Managing email obj: " & pendingEmail.id

  let userData = getUserData(pendingEmail.userID)

  # Check if the email is archived before attempting to send
  if pendingEmail.mailCategory == "archived":
    echo "Email with mailID " & pendingEmail.mailID & " is archived - skipping send"

    # Update the status of the pending email to 'skipped'
    pg.withConnection conn:
      exec(conn, sqlUpdate(
        table = "pending_emails",
        data  = [
          "status",
          "updated_at"
        ],
        where = [
          "id = ?"
        ]),
        "skipped",
        $(now().utc).format("yyyy-MM-dd HH:mm:ss"),
        pendingEmail.id
      )

    # Schedule the next flow step if applicable (even though we skipped this email)
    if pendingEmail.flowStepID != "":
      echo "Email was archived, but continuing to next flow step"
      scheduleNextFlowStep(pendingEmail, getMailData(pendingEmail.flowStepID))

    return

  var mailData: seq[string]
  if pendingEmail.manualHTML != "":
    # Manual HTML emails don't have a mailID, so they can't be archived
    mailData = @[pendingEmail.manualSubject, pendingEmail.manualHTML]
  else:
    pg.withConnection conn:
      mailData = getRow(conn, sqlSelect(
        table = "mails",
        select = [
          "subject",
          "contentHTML",
        ],
        where = [
          "id = ?"
        ]
      ), pendingEmail.mailID)

  #echo "Email being sent to " & userData[1]
  # Send the email
  let sendData = sendMailMimeNow(
    contactID = pendingEmail.userID,
    subject = (if pendingEmail.manualSubject.len > 0: pendingEmail.manualSubject else: mailData[0]),
    message = mailData[1],
    recipient = userData[1],
    mailUUID = pendingEmail.uuid
  )

  if not sendData.success:
    echo "Failed to send email: mailID = " & pendingEmail.id & " - Err = " & sendData.messageID
    return

  # Update the status of the pending email
  pg.withConnection conn:
    exec(conn, sqlUpdate(
      table = "pending_emails",
      data  = [
        "status",
        "message_id",
        "sent_at",
        "updated_at"
      ],
      where = [
        "id = ?"
      ]),
      "sent",
      sendData.messageID,
      $(now().utc).format("yyyy-MM-dd HH:mm:ss"),
      $(now().utc).format("yyyy-MM-dd HH:mm:ss"),
      pendingEmail.id
    )

  # Schedule the next flow step if applicable
  if pendingEmail.flowStepID != "":
    scheduleNextFlowStep(pendingEmail, getMailData(pendingEmail.flowStepID))

  sleep((1000 / sendData.mailsPerSecond).toInt())



proc mailPendingEmails*() {.thread.} =
  echo "Starting thread: mail"
  while true:
    let msg = mailChannel.recv()
    sendPendingEmail(msg)
