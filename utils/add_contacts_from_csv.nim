

import std/[
  httpclient,
  json,
  os,
  parsecsv,
  rdstdin,
  strutils,
  times
]


proc parseCsv(csvFile: string): seq[tuple[email: string, name: string, flowStep: int]] =
  var p: CsvParser
  p.open(csvFile)
  p.readHeaderRow()
  var totalRows = 0
  while p.readRow():
    totalRows += 1
    var contact: tuple[email: string, name: string, flowStep: int] = (email: "", name: "", flowStep: 1)
    for col in items(p.headers):
      if col == "email":
        contact.email = p.rowEntry(col).toLowerAscii()
      elif col == "name":
        contact.name = p.rowEntry(col)
      elif col == "flow_step":
        contact.flowStep = p.rowEntry(col).parseInt()
    if contact.email == "" or contact.name == "":
      echo "Skipping row: ", p
      continue
    result.add(contact)
    echo "Parsed contact: ", contact

  echo "\nParsed ", result.len(), " contacts from ", totalRows, " rows"
  p.close()


proc addContactAndAddToList(client: HttpClient, endpoint: string, email: string, name: string, listIdentifier: string, flowStep: int) =
  let
    url = endpoint & "/api/event"

  let body = %*{
    "event": "contact-create",
    "email": email,
    "name": name,
    "double_opt_in": false,
    "flow_step": flowStep,
    "list": listIdentifier
  }

  let response = client.request(url, httpMethod = HttpPost, body = $body)
  if not response.code().is2xx():
    echo "⚠️ Error adding contact: ", response.body, " for email: ", email
  else:
    echo "✅ Contact added: ", response.body, " for email: ", email


proc addContactToList(client: HttpClient, endpoint: string, email: string, name: string, listIdentifier: string, flowStep: int) =
  let
    url = endpoint & "/api/event"
  let body = %*{
    "event": "contact-add-to-list",
    "email": email,
    "list": listIdentifier,
    "flow_step": flowStep,
  }

  let response = client.request(url, httpMethod = HttpPost, body = $body)
  if not response.code().is2xx():
    echo "⚠️ Error adding contact to list: ", response.body, " for email: ", email
  else:
    echo "✅ Contact added to list: ", response.body, " for email: ", email


proc contactExists(client: HttpClient, endpoint: string, email: string): bool =
  let
    url = endpoint & "/api/event"
  let body = %*{
    "event": "contact-exists",
    "email": email,
  }
  let response = client.request(url, httpMethod = HttpPost, body = $body)
  if not response.code().is2xx():
    echo "⚠️ Error checking if contact exists: ", response.body, " ", response.code(), " for email: ", email
    return false

  let responseBody = parseJson(response.body)
  if responseBody["success"].getBool() and responseBody["exists"].getBool():
    return true
  else:
    return false



proc loopContacts(csvFile: string, endpoint: string, bearerToken: string, listIdentifier: string) =
  let contacts = parseCsv(csvFile)
  var line: string
  let ok = readLineFromStdin("Continue with adding contacts? (y/n): ", line)
  if not ok:
    echo "Exiting..."
    quit(1)
  if line != "y":
    echo "Exiting..."
    quit(1)

  let client = newHttpClient()
  client.headers = newHttpHeaders({"Content-Type": "application/json", "Authorization": "Bearer " & bearerToken})

  var newContacts = 0
  var existingContacts = 0
  for contact in contacts:
    if contactExists(client, endpoint, contact.email):
      addContactToList(client, endpoint, contact.email, contact.name, listIdentifier, contact.flowStep)
      existingContacts += 1
    else:
      addContactAndAddToList(client, endpoint, contact.email, contact.name, listIdentifier, contact.flowStep)
      newContacts += 1

  echo "✅ Added ", newContacts, " new contacts"
  echo "✅ Added ", existingContacts, " existing contacts"


when isMainModule:

  echo "\nUsage: add_contacts_from_csv <csv_file> <endpoint> <bearer_token> <list_identifier>"
  echo ""
  echo "CLI parameters:"
  echo "./add_contacts_from_csv <csv_file> <endpoint> <bearer_token> <list_identifier>"
  echo "- csv_file: CSV file to add the contacts from"
  echo "- endpoint: Endpoint is the URL of the Nimletter instance"
  echo "- bearer_token: Bearer token is the API key for the Nimletter instance"
  echo "- list_identifier: List identifier is the identifier of the list to add the contacts to"
  echo ""
  echo "CSV file:"
  echo "- Required column: email"
  echo "- Required column: name"
  echo "- Optional column: flow_step (default: 1)"
  echo ""
  echo "Example: ./add_contacts_from_csv mylist.csv https://nimletter.mailer.com 2d45f559-f50c-4e39-8e93-24f50b742732 my-list-id\n"

  if paramCount() != 4:
    quit(1)

  let
    csvFile = paramStr(1)
    endpoint = paramStr(2)
    bearerToken = paramStr(3)
    listIdentifier = paramStr(4)

  loopContacts(csvFile, endpoint, bearerToken, listIdentifier)