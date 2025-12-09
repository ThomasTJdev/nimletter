
import
  std/[
    locks,
    os,
    strutils,
    times
  ]

import
  sqlbuilder

import
  ../database/database_connection,
  ../database/database_queries,
  ../email/email_channel,
  ../scheduling/schedule_mail


var gPendingEmailLock*: Lock
initLock(gPendingEmailLock)



proc checkAndSendScheduledEmails*(minutesBack = 5, until = now().utc, isBackupRun = false) =

  acquire(gPendingEmailLock)

  var pendingEmails: seq[seq[string]]
  pg.withConnection conn:
    let
      rightNow = until.format("yyyy-MM-dd HH:mm:ss")
      timeThreshold = (now().utc - initDuration(minutes = minutesBack)).format("yyyy-MM-dd HH:mm:ss")

    pendingEmails = getAllRows(conn, sqlSelect(
        table = "pending_emails",
        select = [
          "pending_emails.id",
          "pending_emails.user_id",
          "pending_emails.list_id",
          "pending_emails.flow_id",
          "pending_emails.flow_step_id",
          "pending_emails.trigger_type",
          "pending_emails.scheduled_for",
          "pending_emails.status",
          "pending_emails.message_id",
          "pending_emails.created_at",
          "pending_emails.updated_at",
          "pending_emails.uuid",
          "pending_emails.mail_id",
          "pending_emails.manual_html",
          "pending_emails.manual_subject"
        ],
        where = [
          "pending_emails.scheduled_for <= ?",
          "pending_emails.scheduled_for >= ?",
          "pending_emails.status = 'pending'" & (if isBackupRun: " OR pending_emails.status = 'inprogress'" else: "")
        ]
      ),
      rightNow,
      timeThreshold
    )

    exec(conn, sqlUpdate(
      table = "pending_emails",
      data  = [
        "status"
      ],
      where = [
        "pending_emails.scheduled_for <= ?",
        "pending_emails.scheduled_for >= ?",
        "pending_emails.status = 'pending'"
      ]
    ), "inprogress", rightNow, timeThreshold)

  release(gPendingEmailLock)

  for pendingEmail in pendingEmails:
    echo "Sending email obj to thread: " & pendingEmail[0]

    mailChannel.send PendingMailObj(
      id: pendingEmail[0],
      userID: pendingEmail[1],
      listID: pendingEmail[2],
      flowID: pendingEmail[3],
      flowStepID: pendingEmail[4],
      triggerType: pendingEmail[5],
      scheduledFor: pendingEmail[6],
      status: pendingEmail[7],
      messageID: pendingEmail[8],
      createdAt: pendingEmail[9],
      updatedAt: pendingEmail[10],
      uuid: pendingEmail[11],
      mailID: pendingEmail[12],
      manualHTML: pendingEmail[13],
      manualSubject: pendingEmail[14]
    )

