# !! WE ARE INCLUDING THE SMTP LIBRARY HERE !!
when NimMajor >= 2:
  include smtp
else:
  include std/smtp
# !! WE ARE INCLUDING THE SMTP LIBRARY HERE !!

proc sendMailGetReply*(smtp: Smtp | AsyncSmtp, fromAddr: string,
              toAddrs: seq[string], msg: string): Future[string] {.multisync.} =
  ## Sends `msg` from `fromAddr` to the addresses specified in `toAddrs`.
  ## Messages may be formed using `createMessage` by converting the
  ## Message into a string.
  ##
  ## You need to make sure that `fromAddr` and `toAddrs` don't contain
  ## any newline characters. Failing to do so will raise `AssertionDefect`.
  doAssert(not (toAddrs.containsNewline() or fromAddr.contains({'\c', '\L'})),
          "'toAddrs' and 'fromAddr' shouldn't contain any newline characters")

  await smtp.debugSend("MAIL FROM:<" & fromAddr & ">\c\L")
  await smtp.checkReply("250")
  for address in items(toAddrs):
    await smtp.debugSend("RCPT TO:<" & address & ">\c\L")
    await smtp.checkReply("250")

  # Send the message
  await smtp.debugSend("DATA" & "\c\L")
  await smtp.checkReply("354")
  await smtp.sock.send(msg & "\c\L")
  await smtp.debugSend(".\c\L")

  #
  # Main change is here. Since smtp.sock is private we need to include the
  # library and recreate the sendMail proc() to return the message ID
  #
  # await smtp.checkReply("250") # Original code
  var line = await smtp.debugRecv()
  if not line.startsWith("250"):
    await quitExcpt(smtp, "Expected " & "250" & " reply, got: " & line)
  let lineSplit = line.split(' ')
  if lineSplit.len < 2:
    await quitExcpt(smtp, "Expected " & "250" & " reply, got: " & line)
  return lineSplit[2]
