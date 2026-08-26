import
  std/[
    base64,
    random,
    re,
    strutils,
    times
  ]

import
  sqlbuilder

import
  ../database/database_connection


randomize()

const htmlHeader = """<!DOCTYPE html><html lang="EN" style="background:#FAFAFA;min-height:100%;"><head><meta charset="UTF-8"><meta content="width=device-width, initial-scale=1.0" name="viewport"><title>$1</title><style>@media only screen and (max-width:620px){.nl-mobile-outer{padding-left:8px!important;padding-right:8px!important}}</style></head><body>"""

const htmlFooter = "</body></html>"

const htmlTracker = """<div style="width: 100%; text-align: center;"><img src="$1/webhook/tracking/$2/open/$3"></div>"""

const unsubscribeLink = """<div style="width: 100%; text-align: center;"><a href="$1">Unsubscribe</a></div>"""




proc finalizeEmail(
    message, subjectChecked, userUUID, hostname, mailUUID: string,
    ignoreUnsubscribe = false
  ): string =
  if ignoreUnsubscribe:
    return (
      htmlHeader.format(subjectChecked) &
      message &
      htmlTracker.format(hostname, (if mailUUID != "": mailUUID else: "pure"), $rand(1000)) &
      htmlFooter
    )

  else:
    return (
      htmlHeader.format(subjectChecked) &
      message &
      unsubscribeLink.format(hostname & "/unsubscribe?contactUUID=" & userUUID) &
      htmlTracker.format(hostname, (if mailUUID != "": mailUUID else: "pure"), $rand(1000)) &
      htmlFooter
    )


template linkReplace() =
  ## Link replacing
  ## 1. Get all href="..." links and convert it to base64
  ## 2. Replace the link with a `customurl/base64` string
  if mailUUID != "":
    let reLink = re("""href="([^"]+)"""")
    let links = findAll(result, reLink)
    for link in links:
      if link.contains("/subscribe/optin"):
        continue

      let
        base64 = encode(link.split("\"")[1])

      const
        baseUrl = "/webhook/tracking/$1/click/$2"

      result = result.replace(link, "href=\"" & hostname & baseUrl.format(mailUUID, base64) & "\"")


proc emailVariableReplace*(contactID, message, subjectChecked: string, mailUUID = "", ignoreUnsubscribe = false): string =
  ## Replace variables in a message.
  ##
  ## Variables are defined by {{ and }}. It holds a variable name,
  ## and maybe a default value, like {{ name | default }}.
  ## If the variable is not found, it will be replaced by the default value.
  ## If the default value is not found, it will be replaced by an empty string.
  ##
  ## Internal fields can be overridden by using metadata. Internal fields are:
  ##  - firstname: Will use the first name of the user (split(" ")[0]).
  ##  - lastname: Will use the last name of the user (split(" ")[1]).
  ##  - name: Will use the full name of the user.
  ##  - email: Will use the email of the user.

  result = message

  let reRes = re("""{{\s*(\w+)\s*(?:\|\s*(\w+))?\s*}}""")
  let matches = findAll(message, reRes)


  const internalFields = @["firstname", "lastname", "name", "email", "pagename", "hostname", "uuid"]
  var
    fieldVariable: seq[string]
    fieldDefaults: seq[string]
    fieldArgs: seq[string]
    matchesChecked: seq[string]

  #
  # Index matches and fields
  #
  for match in matches:
    if match in matchesChecked:
      continue

    let
      matchSeq = match.strip(chars = {' ', '{', '}'}).split("|")

    let
      base    = (matchSeq[0]).strip()
      default = (if matchSeq.len() == 2: matchSeq[1] else: "").strip()

    if base in internalFields:
      case base
      of "firstname":
        fieldVariable.add("split_part(name, ' ', 1) AS first_name")
      of "lastname":
        fieldVariable.add("""split_part(regexp_replace(name, '.*\s', '', 'g'), ' ', 1) AS last_name""")
      of "name":
        fieldVariable.add("name")
      of "email":
        fieldVariable.add("email")
      of "contactUUID":
        fieldVariable.add("uuid")
      else:
        continue
    else:
      # All non-internal fields are stored in the metadata column
      fieldVariable.add("contacts.meta->>?")
      fieldArgs.add(base)

    fieldDefaults.add(default)
    matchesChecked.add(match)

  fieldArgs.add(contactID)
  fieldVariable.add("uuid")

  #
  # Query the database
  #
  var
    userData: seq[string]
    mainSettings: seq[string]
  pg.withConnection conn:
    userData = getRow(conn, sqlSelect(
      table = "contacts",
      select = fieldVariable,
      where = ["id = ?"]
    ), fieldArgs)

    mainSettings = getRow(conn, sqlSelect(
      table = "settings",
      select = ["hostname", "page_name"],
      where = ["id = 1"]
    ))

  let
    hostname = mainSettings[0]
    pageName = mainSettings[1]



  #
  # If there's no special attributes, we can just return the message.
  #
  if matchesChecked.len == 0:
    linkReplace()
    return finalizeEmail(
      result,
      subjectChecked,
      userData[userData.high],
      hostname,
      mailUUID,
      ignoreUnsubscribe
    )

  #
  # Go attribute crazy
  #
  var multi: seq[(string, string)]
  multi.add(("{{ pagename }}", pageName))
  multi.add(("{{ hostname }}", hostname))
  multi.add(("{{ contactUUID }}", userData[userData.high]))
  multi.add(("{{ unsubscribe_href }}", hostname & "/unsubscribe?contactUUID=" & userData[userData.high]))
  multi.add(("{{ unsubscribe_link }}", "<a href=\"" & hostname & "/unsubscribe?contactUUID=" & userData[userData.high] & "\">Unsubscribe</a>"))


  for i in 0..matchesChecked.high:
    let
      match   = matchesChecked[i]
      field   = fieldVariable[i]
      default = fieldDefaults[i]
      dbvalue = userData[i]

    if dbvalue == "":
      multi.add((match, default))
    else:
      multi.add((match, dbvalue))

  result = result.multiReplace(multi)

  linkReplace()

  return finalizeEmail(
      result,
      subjectChecked,
      userData[userData.high],
      hostname,
      mailUUID,
      ignoreUnsubscribe
    )

