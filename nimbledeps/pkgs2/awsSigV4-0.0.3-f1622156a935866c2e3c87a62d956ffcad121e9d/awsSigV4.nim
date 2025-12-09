

#[

  Code origins from:
    https://github.com/guzba/depot
    https://github.com/disruptek/sigv4

  Purpose for rewrite originated from the dependency, balls, in the
  sigv4 package.

  This code only relies on crunchy.

]#


import
  std/[
    algorithm,
    httpclient,
    json,
    sequtils,
    strutils,
    tables,
    times,
    uri
  ]

import crunchy

type
  S3ContentDisposition* = enum
    CDTinline
    CDTattachment
    CDTignore

  SigningAlgo* = enum
    SHA256 = "AWS4-HMAC-SHA256"
    UnsignedPayload = "UNSIGNED-PAYLOAD"

  EncodedHeaders* = tuple[signed: string; canonical: string]
  KeyValue = tuple[key: string; val: string]

const
  dateISO8601 = initTimeFormat "yyyyMMdd"
  basicISO8601 = initTimeFormat "yyyyMMdd\'T\'HHmmss\'Z\'"


proc makeDateTime*(): string =
  let now = getTime()
  result = now.utc.format(basicISO8601)

proc makeDate*(date: string = ""): string =
  if date == "":
    let now = getTime()
    result = now.utc.format(dateISO8601)
  else:
    result = date[date.low .. ("YYYYMMDD".len-1)]



proc encodedQuery(input: openArray[KeyValue]): string =
  ## encoded a series of key/value pairs as a query string
  let
    query = input.sortedByIt (it.key, it.val)
  for q in query.items:
    if result.len > 0:
      result.add "&"
    result.add encodeUrl(q.key, usePlus = false)
    result.add "="
    result.add encodeUrl(q.val, usePlus = false)

proc toQueryValue(node: JsonNode): string =
  ## render a json node as a query string value
  assert node != nil
  if node == nil:
    raise newException(ValueError, "pass me a JsonNode")
  result = case node.kind
  of JString:
    node.getStr
  of JInt, JFloat, JBool:
    $node
  of JNull:
    ""
  else:
    raise newException(ValueError, $node.kind & " unsupported")

proc encodedQuery(node: JsonNode): string =
  ## encoded a series of key/value pairs as a query string
  var query: seq[KeyValue]
  assert node != nil and node.kind == JObject
  if node == nil or node.kind != JObject:
    raise newException(ValueError, "pass me a JObject")
  for q in node.pairs:
    query.add (key: q.key, val: q.val.toQueryValue)
  result = encodedQuery(query)

proc trimAll(s: string): string =
  ## remove surrounding whitespace and de-dupe internal spaces
  result = s.strip(leading=true, trailing=true)
  while "  " in result:
    result = result.replace("  ", " ")

proc encodedHeaders(headers: HttpHeaders): EncodedHeaders =
  ## convert http headers into encoded header string
  var
    signed, canonical: string
    heads: seq[KeyValue]
  for h in headers.table.pairs:
    heads.add (
      key: h[0].strip.toLowerAscii,
      val: h[1].map(trimAll).join(",")
    )
  heads = heads.sortedByIt (it.key)
  for h in heads:
    if signed.len > 0:
      signed.add ";"
    signed.add h.key
    canonical.add h.key & ":" & h.val & "\n"
  result = (signed: signed, canonical: canonical)


proc hash*(payload: string; digest: SigningAlgo): string =
  ## hash an arbitrary string using the given algorithm
  case digest
  of SHA256: result = sha256(payload).toHex()
  of UnsignedPayload: result = $UnsignedPayload


proc canonicalRequest(
  httpMethod: HttpMethod,
  url: Uri,
  headers: HttpHeaders,
  payload: string,
  digest: SigningAlgo = SHA256
): string =
  let head = encodedHeaders(headers)
  result = ($httpmethod).toUpperAscii() & '\n'
  result.add url.path & "\n"
  result.add url.query & "\n"
  result.add head.canonical & '\n'
  result.add head.signed & '\n'
  result.add hash(payload, digest)


proc canonicalRequest*(
  httpMethod: HttpMethod,
  url: string,
  query: JsonNode, #params: QueryParams,
  headers: HttpHeaders,
  payload: string,
  digest: SigningAlgo = SHA256
): string =
  ## produce the canonical request for signing purposes
  var uri = parseUri(url)
  uri.path = uri.path
  uri.query = encodedQuery(query)
  result = canonicalRequest(httpMethod, uri, headers, payload, digest)


proc credentialScope*(region, service, date: string): string =
  date.makeDate() & '/' &
  region.toLowerAscii() & '/' &
  service.toLowerAscii() &
  "/aws4_request"


proc stringToSign*(
  request, credentialScope, date: string,
  digest: SigningAlgo = SHA256
): string =
  result = newStringOfCap(
    ($digest).len + 1 +
    date.len + 1 +
    credentialScope.len + 1 +
    64  # SHA256 hex length
  )
  result.add $digest
  result.add '\n'
  result.add date
  result.add '\n'
  result.add credentialScope
  result.add '\n'
  result.add sha256(request).toHex()


proc calculateSignature*(
  secret: string,
  date: string,
  region: string,
  service: string,
  tosign: string,
  digest: SigningAlgo = SHA256
): string =
  ## compute a signature using secret, string-to-sign, and other details
  block:
    case digest
    of SHA256:
      let
        kDate = hmacSha256("AWS4" & secret, makeDate(date))
        kRegion = hmacSha256(kDate, region)
        kService = hmacSha256(kRegion, service)
        kSigning = hmacSha256(kService, "aws4_request")
      result = hmacSha256(kSigning, tosign).toHex()
    of UnsignedPayload:
      discard
