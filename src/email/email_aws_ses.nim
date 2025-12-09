
import
  std/[
    json,
    httpclient,
    os,
    strutils,
    random,
    wordwrap
  ]

from std/base64 import encode
from std/os import getEnv

import
  awsSigV4,
  mime,
  sqlbuilder

import
  ./email_types

proc sendAwsSes*(
  smtpData: SmtpData,
  multi: MimeMessage,
  recipient: string,
  replyTo: string = ""
): tuple[success: bool, messageID: string, errorMessage: string] =

  # ---------- SES endpoint ----------
  let region   = "eu-west-1"
  let endpoint = "https://email." & region & ".amazonaws.com/v2/email/outbound-emails"

  # Convert MIME tree → raw MIME string
  let rawMime   = $multi.finalize()
  let rawBase64 = base64.encode(rawMime)

  # ---------- JSON payload ----------
  var payloadJson = %*{
    "FromEmailAddress": smtpData.smtpFromName & " <" & smtpData.smtpFromEmail & ">",
    "Destination": { "ToAddresses": [recipient] },
    "Content": {
      "Raw": { "Data": rawBase64 }
    }
  }

  when defined(dev):
    echo payloadJson

  if replyTo.len > 0:
    payloadJson["ReplyToAddresses"] = %* [replyTo]

  let payload = $payloadJson

  # ---------- Prepare SigV4 signing context ----------
  let service = "ses"
  let datetime = makeDateTime()   # AWS-format timestamp
  let scope    = credentialScope(region = region, service = service, date = datetime)

  # Host header for canonical request
  let host = "email." & region & ".amazonaws.com"
  #var headers = newHttpHeaders(@[("Host", host)])

  # Required headers for SES POST requests
  var headers = newHttpHeaders({
    "Host": host,
    "Content-Type": "application/json",
    "X-Amz-Date": datetime
  })

  # SES API uses header auth, NOT query auth → query is empty {}
  var query = %*{}   # << IMPORTANT

  # Digest: SES expects SHA256(payload), NOT UnsignedPayload
  let digest = SHA256

  # ---------- Build canonical request ----------
  let request = canonicalRequest(
    httpMethod = HttpPost,
    url        = endpoint,
    query      = query,
    headers    = headers,
    payload    = payload,
    digest     = digest
  )

  # ---------- Build string-to-sign ----------
  let sts = stringToSign(
    request,
    scope,
    date  = datetime,
    digest = SHA256
  )


  # ---------- Calculate signature ----------
  let signature = calculateSignature(
    secret  = smtpData.smtpPass,  # OR your secret key variable
    date    = datetime,
    region  = region,
    service = service,
    tosign  = sts,
    digest  = SHA256
  )

  # ---------- Build Authorization header ----------
  let authHeader = "AWS4-HMAC-SHA256 Credential=" & smtpData.smtpUser &
                  "/" & scope &
                  ", SignedHeaders=host;" &
                  "content-type;x-amz-date, " &
                  "Signature=" & signature

  # ---------- Final HTTP headers ----------
  headers = newHttpHeaders({
    "Host": host,
    "Content-Type": "application/json",
    "X-Amz-Date": datetime,
    "Authorization": authHeader
  })

  # ---------- Execute HTTPS request ----------
  var client = newHttpClient()

  try:
    let resp = client.request(
      url        = endpoint,
      httpMethod = HttpPost,
      headers    = headers,
      body       = payload
    )

    if int(resp.code) in 200..299:
      # SES v2 returns {"MessageId": "..."}
      let bodyJson = parseJson(resp.body)
      let msgId = if bodyJson.hasKey("MessageId"): bodyJson["MessageId"].getStr() else: "unknown"
      return (true, msgId, "")
    else:
      echo "SES error: ", resp.code, " ", resp.body
      return (false, "email_failed_" & $rand(100000), "")

  except CatchableError:
    echo "SES HTTPS exception: ", getCurrentExceptionMsg()
    return (false, "email_failed_" & $rand(100000), "")