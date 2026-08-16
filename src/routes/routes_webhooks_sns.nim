
import
  std/[
    base64,
    json,
    locks,
    strutils,
    tables,
    times
  ]

from std/os import getEnv


import
  mummy, mummy/routers,
  mummy_utils


import
  awsSES_SNS,
  sqlbuilder


import
  ../database/database_connection,
  ../database/database_queries,
  ../scheduling/schedule_mail,
  ../utils/assets,
  ../utils/auth,
  ../utils/validate_data,
  ../webhook/webhook_events



proc updateUserBounce(mail: MailBounce) =

  var mailData: PendingMail
  pg.withConnection conn:
    mailData = getDataFromPendingEmails(conn, mail.messageID)

    if mailData.id == "":
      return

  blockContactFromSending(
    userID = mailData.userID,
    bouncedPendingEmailID = mailData.id,
    bounceType = $mail.bounceType,
    bounceSubtype = $mail.bounceSubType,
    diagnosticCode = mail.diagnosticCode,
    bounceStatus = mail.status,
    messageID = mail.messageID
  )

  let data = %* {
      "success": true,
      "bounceType": $mail.bounceType,
      "bounceSubType": $mail.bounceSubType,
      "email": mailData.userEmail,
      "username": mailData.userName,
      "status": mail.status,
      "diagnosticCode": mail.diagnosticCode,
      "messageID": mail.messageID,
      "event": "email_bounced"
    }

  parseWebhookEvent(email_bounced, data)


proc updateUserComplaint(mail: MailComplaint) =

  var mailData: PendingMail
  pg.withConnection conn:
    mailData = getDataFromPendingEmails(conn, mail.messageID)

    if mailData.id == "":
      echo "No pending email found for complaint: " & mail.messageID
      return

    exec(conn, sqlUpdate(
      table = "contacts",
      data  = [
        "complained_at = CURRENT_TIMESTAMP",
      ],
      where = "id = ?"
    ), mailData.userID)

    exec(conn, sqlUpdate(
      table = "pending_emails",
      data  = [
        "status = 'cancelled'",
        "updated_at = CURRENT_TIMESTAMP",
      ],
      where = "user_id = ?"
    ), mailData.userID)

    exec(conn, sqlUpdate(
      table = "pending_emails",
      data  = [
        "status = 'complained'",
        "updated_at = CURRENT_TIMESTAMP",
      ],
      where = "id = ?"
    ), mailData.id)

    # complained_at uses the column DEFAULT; sqlInsert cannot take "col = CURRENT_TIMESTAMP".
    exec(conn, sqlInsert(
      table = "email_complaints",
      data  = [
        "pending_email_id",
        "user_id",
        "complaint_feedback",
        "message_id",
      ]),
      mailData.id, mailData.userID, mail.complaintFeedbackType, mail.messageID
    )

  let data = %* {
      "success": true,
      "complaintFeedbackType": $mail.complaintFeedbackType,
      "arrivalDate": mail.arrivalDate,
      "email": mailData.userEmail,
      "username": mailData.userName,
      "messageID": mail.messageID,
      "event": "email_complained"
    }

  parseWebhookEvent(email_complained, data)


proc updateUserOpen(mail: MailOpen) =

  var
    match: bool
    hasTrigger: bool
    triggerData: PendingMail
    mailData: PendingMail

  pg.withConnection conn:
    mailData = getDataFromPendingEmails(conn, mail.messageID)
    if mailData.id == "":
      echo "No pending email found"
    else:
      match = true

    if match:
      exec(conn, sqlInsert(
        table = "email_opens",
        data  = [
          "pending_email_id",
          "user_id",
          "device_info",
          "ip_address",
          "message_id",
        ]),
        mailData.id,
        mailData.userID,
        mail.userAgent,
        mail.ipAddress,
        mail.messageID
      )

      # Flow-trigger lookup only makes sense for flow emails; opt-in/one-off
      # emails have no flowID and therefore no next step to schedule.
      if mailData.flowID != "":
        hasTrigger = true
        triggerData = getDataFromPendingEmailsTrigger(
                    conn, mailData.flowID, $(mailData.stepNumber + 1), mailData.userID)

  if match and hasTrigger and triggerData.triggerType == "open" and triggerData.status == "pending":
    triggerScheduleEmail(triggerData)

  # Always fire the outbound webhook when a match was found, regardless of
  # whether the email belongs to a flow or not.
  if match:
    let data = %* {
        "success": true,
        "userAgent": mail.userAgent,
        "email": mailData.userEmail,
        "username": mailData.userName,
        "messageID": mail.messageID,
        "event": "email_opened"
      }
    parseWebhookEvent(email_opened, data)


proc updateUserClick(mail: MailClick) =

  var
    match: bool
    triggerData: PendingMail
    mailData: PendingMail

  pg.withConnection conn:
    mailData = getDataFromPendingEmails(conn, mail.messageID)
    if mailData.id == "":
      echo "No pending email found"
    else:
      match = true

    if match:
      exec(conn, sqlInsert(
        table = "email_clicks",
        data  = [
          "pending_email_id",
          "user_id",
          "device_info",
          "ip_address",
          "link_url",
          "message_id",
        ]),
        mailData.id,
        mailData.userID,
        mail.userAgent,
        mail.ipAddress,
        mail.link,
        mail.messageID
      )

      # Flow-trigger lookup only makes sense for flow emails; opt-in/one-off
      # emails have no flowID and therefore no next step to schedule.
      if mailData.flowID != "":
        triggerData = getDataFromPendingEmailsTrigger(
                    conn, mailData.flowID, $(mailData.stepNumber + 1), mailData.userID)

  if match and triggerData.triggerType == "click" and triggerData.status == "pending":
    triggerScheduleEmail(triggerData)

  # Always fire the outbound webhook when a match was found, regardless of
  # whether the email belongs to a flow or not.
  if match:
    let data = %* {
        "success": true,
        "userAgent": mail.userAgent,
        "link": mail.link,
        "email": mailData.userEmail,
        "username": mailData.userName,
        "messageID": mail.messageID,
        "event": "email_clicked"
      }
    parseWebhookEvent(email_clicked, data)


var webhooksSnsRouter*: Router

webhooksSnsRouter.post("/webhook/incoming/sns/@key",
proc(request: Request) =
  ## AWS SNS / SES event intake.
  ## Must never surface a 5xx: SNS retries on 5xx and will flood monitoring.
  ## Auth/parse failures → 400. Processing failures are logged and still 200.
  when defined(dev):
    echo "Received SNS webhook"

  if @"key" != getEnv("SNS_WEBHOOK_SECRET", "secret"):
    resp Http400

  let (snsSuccess, snsMsg) = snsParseJson(request.body)
  if not snsSuccess:
    echo "Error parsing SNS JSON"
    echo request.body
    resp Http400

  try:
    # Case through the different types of events
    case snsParseEventType(snsMsg)
    of SNSSubscriptionConfirmation:
      let sub = snsSubscriptionConfirmation(snsMsg)
      echo sub.message
      echo sub.subscribeURL


    of Bounce:
      # 0.1.2+: parse failures return @[] instead of raising.
      let mailBounce = snsParseBounce(snsMsg)
      for mail in mailBounce:
        if mail.parsingSucceeded:
          updateUserBounce(mail)


    of Complaint:
      let mailComplaint = snsParseComplaint(snsMsg)
      for mail in mailComplaint:
        if mail.parsingSucceeded:
          updateUserComplaint(mail)


    of Delivery:
      let mailDelivery = snsParseDelivery(snsMsg)
      if mailDelivery.parsingSucceeded:
        echo $mailDelivery.email & " - " & mailDelivery.messageID
      else:
        echo "Error parsing SNS delivery payload"


    of Open:
      let mailOpen = snsParseOpen(snsMsg)
      if mailOpen.parsingSucceeded:
        updateUserOpen(mailOpen)
      else:
        echo "Error parsing SNS open payload"


    of Click:
      let mailClick = snsParseClick(snsMsg)
      if mailClick.parsingSucceeded:
        updateUserClick(mailClick)
      else:
        echo "Error parsing SNS click payload"


    else:
      echo "Unknown event type: " & request.body

  except CatchableError as err:
    # Acknowledge the notification so SNS stops retrying; the error is logged
    # for investigation (DB blip, bad row, outbound webhook side effects, etc.).
    echo "SNS webhook processing error: " & err.msg
    echo request.body

  resp Http200

)


const pathTracker = "/assets/images/nimletter_icon.png"

template handleTracking() =
  let mailuuid = @"mailuuid"

  if not mailuuid.isValidUUID() and mailuuid != "pure":
    resp Http400

  var mailID: string
  if mailuuid.isValidUUID():
    pg.withConnection conn:
      mailID = getValue(conn, sqlSelect(
        table   = "pending_emails",
        select  = ["message_id"],
        where   = ["uuid = ?"]
      ), mailuuid)

  if mailID == "" and @"action" == "open":
    acquire(gFilecacheLock)
    try:
      var headers: HttpHeaders
      {.gcsafe.}:
        headers["Content-Type"] = "image/png"
        request.respond(200, headers, assets[pathTracker].filedata)
    except:
      request.respond(400)

    release(gFilecacheLock)
    return

  elif mailID == "":
    resp Http404

  let action = @"action"
  if action notin ["open", "click"]:
    resp Http400


  # User-Agent:
  #   Many rows show only "Mozilla/5.0", which is basically useless.
  #   Proxies and scanners often strip UA details.
  #   Outlook desktop and OneOutlook show up well, but Gmail (via ggpht.com) will always hide the real UA.
  if action == "open":
    var mailOpen = MailOpen(
      messageID: mailID,
      timestamp: $now().utc,
      ipAddress: request.ip,
      userAgent: (if request.headers.hasKey("User-Agent"): request.headers["User-Agent"] else: "")
    )

    updateUserOpen(mailOpen)

    acquire(gFilecacheLock)
    try:
      var headers: HttpHeaders
      {.gcsafe.}:
        headers["Content-Type"] = "image/png"
        request.respond(200, headers, assets[pathTracker].filedata)
    except:
      request.respond(400)

    release(gFilecacheLock)
    return


  elif action == "click":
    let link = decode(@"do")

    var mailClick = MailClick(
      messageID: mailID,
      timestamp: $now().utc,
      ipAddress: request.ip,
      userAgent: (if request.headers.hasKey("User-Agent"): request.headers["User-Agent"] else: ""),
      link: decode(@"do")
    )

    updateUserClick(mailClick)

    redirect(link)


webhooksSnsRouter.get("/webhook/tracking/@mailuuid/@action/@do",
proc(request: Request) =
  handleTracking()
)


webhooksSnsRouter.get("/webhook/tracking/@mailuuid/@action/@do/@notused",
proc(request: Request) =
  handleTracking()
)