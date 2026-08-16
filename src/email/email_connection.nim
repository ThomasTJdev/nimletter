
import
  std/[
    json,
    os,
    strutils,
    random,
    wordwrap
  ]

from std/base64 import encode
from std/os import getEnv

import
  awsSES_SNS,
  awsSigV4,
  mime,
  sqlbuilder


import
  ../database/database_connection,
  ../database/database_queries

import
  ./email_aws_ses,
  ./email_variables,
  ./email_types


randomize()


proc sendMail(
    client: Smtp,
    smtpFrom, recipient: string,
    multi: MimeMessage
  ): (bool, string) =
  # Send email
  try:
    let messageID = client.sendMailGetReply(smtpFrom, @[recipient], $multi.finalize())
    return (true, messageID)
  except:
    return (false, getCurrentExceptionMsg())


proc smtpData(): SmtpData =

  if getEnv("SMTP_HOST") != "":
    let maxMails = getEnv("SMTP_MAILSPERSECOND")
    return (
      smtpHost: getEnv("SMTP_HOST"),
      smtpPort:  getEnv("SMTP_PORT"),
      smtpUser: getEnv("SMTP_USER"),
      smtpPass: getEnv("SMTP_PASSWORD"),
      smtpFromEmail: getEnv("SMTP_FROMEMAIL"),
      smtpFromName: getEnv("SMTP_FROMNAME"),
      smtpMailspersecond: if maxMails != "": maxMails.parseInt() else: 1,
      smtpUseAwsSes: getEnv("SMTP_USE_AWS_SES") == "true"
    )

  else:
    pg.withConnection conn:
      let smtpDB = getRow(conn, sqlSelect(
        table = "smtp_settings",
        select = [
          "smtp_host",
          "smtp_port",
          "smtp_user",
          "smtp_password",
          "smtp_fromemail",
          "smtp_fromname",
          "smtp_mailspersecond",
          "smtp_use_aws_ses"
        ]
      ))

      result = (
        smtpHost: smtpDB[0],
        smtpPort: smtpDB[1],
        smtpUser: smtpDB[2],
        smtpPass: smtpDB[3],
        smtpFromEmail: smtpDB[4],
        smtpFromName: smtpDB[5],
        smtpMailspersecond: smtpDB[6].parseInt(),
        smtpUseAwsSes: smtpDB[7] == "t" or smtpDB[7] == "true"
      )
    return result


proc sendIt(smtpData: SmtpData, recipient: string, multi: MimeMessage): tuple[success: bool, messageID: string, errorMessage: string] =
  ## Basic SMTP connection and send email
  var
    client = newSmtp(useSsl = true)
    success: bool
    messageID: string

  try:
    client.connect(smtpData.smtpHost, Port(smtpData.smtpPort.parseInt()))
  except:
    echo "Error connecting to SMTP server: " & getCurrentExceptionMsg()
    return (false, "", getCurrentExceptionMsg())

  try:
    client.auth(smtpData.smtpUser, smtpData.smtpPass)
  except:
    echo "Error authenticating to SMTP server: " & getCurrentExceptionMsg()
    return (false, "", getCurrentExceptionMsg())

  try:
    (success, messageID) = sendMail(client, smtpData.smtpFromEmail, recipient, multi)
  except:
    echo "Error sending email: " & getCurrentExceptionMsg()
    return (false, "", getCurrentExceptionMsg())

  return (success, messageID, "")



proc sendMailMimeNow*(
      # pendingEmailID: string,
      contactID: string,
      subject, message, recipient: string,
      replyTo: string = "",
      mailUUID: string = "",
      ignoreUnsubscribe = false
  ): tuple[success: bool, messageID: string, mailsPerSecond: int] =

  let smtpData = smtpData()

  if contactID != "" and contactID != "0":
    pg.withConnection conn:
      if contactIsSuppressed(conn, contactID):
        echo "Not sending email: contact has bounced or complained. contactID: " & contactID
        return (false, "contact_blocked", 1)

  # Header
  let subjectChecked =
      if subject.len() <= 75:
        subject.replace("\n", " ")
      else:
        subject.substr(0, 73).replace("\n", " ") & ".."

  var multi = newMimeMessage()
  multi.header["From"]    = smtpData.smtpFromName & " <" & smtpData.smtpFromEmail & ">"
  multi.header["To"]      = @[recipient].mimeList
  multi.header["Subject"] = "=?UTF-8?B?" & base64.encode(subjectChecked) & "?="
  if replyTo != "":
    multi.header["Reply-To"] = replyTo

  let message = emailVariableReplace(contactID, message, subjectChecked, mailUUID, ignoreUnsubscribe).wrapWords(maxLineWidth=250, splitLongWords=false)

  var first = newMimeMessage()
  first.header["Content-Type"]  = "text/html; charset=\"UTF-8\""
  first.body                    = message

  # Add first part to message
  multi.parts.add(first)


  when defined(dev):
    echo "\n"
    echo "##################"
    echo "Email to: " & recipient
    echo "Subject:  " & subject
    echo "Message:  " & message
    echo "##################"
    echo "\n"
    when not defined(forcemail):
      return (true, "dev" & $rand(100000), 1)
  if smtpData.smtpHost == "smtp_host":
    echo "SMTP not configured"
    return (false, "SMTP_not_configured_" & $rand(100000), 1)


  if smtpData.smtpUseAwsSes:
    when defined(dev):
      echo "Sending email via AWS SES"
    let (success, messageID, errorMessage) = sendAwsSes(smtpData, multi, recipient, replyTo)
    if success:
      return (success, messageID, smtpData.smtpMailspersecond)
    else:
      echo "Error sending email (attempt 1 of 1): " & errorMessage
      return (false, "email_failed_" & $rand(100000), smtpData.smtpMailspersecond)

  else:
    # Make SMTP connection
    when defined(dev):
      echo "Sending email via SMTP"
    const retries = 3
    for i in 1..retries:
      let (success, messageID, errorMessage) = sendIt(smtpData, recipient, multi)
      if success:
        return (success, messageID, smtpData.smtpMailspersecond)
      else:
        echo "Error sending email (attempt " & $i & " of " & $retries & "): " & errorMessage
        sleep(500)
    return (false, "email_failed_" & $rand(100000), smtpData.smtpMailspersecond)


