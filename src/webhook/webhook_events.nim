

import
  std/[
    json,
    httpcore,
    httpclient,
    strutils
  ]


import
  sqlbuilder


import
  ../database/database_connection


type
  WebhookEvent* = enum
    contact_created, # DONE
    contact_updated, # DONE
    contact_deleted,
    contact_subscribed,
    contact_unsubscribed,
    contact_optedin, # DONE aka is subscribed
    contact_optedout,# DONE
    email_sent,
    email_opened,    # DONE
    email_clicked,   # DONE
    email_bounced,   # DONE
    email_complained # DONE



proc parseWebhookEvent*(event: WebhookEvent, data: JsonNode) =

  when defined(dev):
    echo "\n##########"
    echo "Webhook event: " & $event
    echo data.pretty
    echo "##########\n"

  var webhooks: seq[seq[string]]
  pg.withConnection conn:
    webhooks = getAllRows(conn, sqlSelect(
      table   = "webhooks",
      select  = ["url", "headers"],
      where   = ["event = ?"],
    ), $event)

  if webhooks.len == 0:
    return

  #
  # Create client
  #
  let client = newHttpClient()
  #
  # Loop through webhooks
  #
  for webhook in webhooks:

    var
      headerJson: JsonNode
      specialHeaders: bool
    try:
      headerJson = parseJson(webhook[1])
      specialHeaders = true
    except:
      specialHeaders = false

    if specialHeaders:
      #
      # Set headers
      #
      var tmpHeaders: seq[tuple[key: string, val: string]]
      for head in headerJson:
        try:
          let headJson = head
          for key in head:
            tmpHeaders.add((headJson["type"].getStr(), headJson["value"].getStr()))
        except:
          continue

      client.headers = newHttpHeaders(tmpHeaders)

    #
    # Post data - wrap in try/except so a network error (DNS failure, timeout,
    # unreachable host) does not propagate and crash the calling route handler.
    #
    try:
      let response = client.request(webhook[0], httpMethod = HttpPost, body = $data)
      if not (code(response)).is2xx():
        echo "Webhook failed: " & webhook[0] & " -> " & response.body
    except CatchableError as err:
      echo "Webhook request error: " & webhook[0] & " -> " & err.msg




