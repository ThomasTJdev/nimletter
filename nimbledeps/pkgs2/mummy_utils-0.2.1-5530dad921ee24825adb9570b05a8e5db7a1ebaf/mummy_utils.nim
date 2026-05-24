# Copyright Thomas T. Jarløv (TTJ) - ttj@ttj.dk

{.push raises: [].}

import
  mummy,
  mummy/routers,
  mummy/multipart

import
  std/[
    cookies,
    json,
    mimetypes,
    strtabs,
    strutils,
    times
  ]

# Set cookies (get string) and samsite enum
export cookies.SameSite

# Access the `.params` with hasKey and pairs (loop)
export strtabs.hasKey, strtabs.pairs

# Exclude HttpHeaders since mummy exports webby's HttpHeaders
import std/httpcore except HttpHeaders
export httpcore except HttpHeaders

# Import query decoder, and `[]` for HttpHeaders
from webby import `[]`
export `[]`, HttpHeaders

import utils/param_utils
export param_utils

import utils/cookie_utils
export cookie_utils

import utils/resp_utils
export resp_utils


#
# Request fields
#
proc body*(request: Request): string =
  ## Get body of request.
  return request.body


proc bodyJson*(request: Request): JsonNode =
  ## Get body as JsonNode.
  try:
    return parseJson(request.body)
  except:
    return newJNull()


proc host*(request: Request): string =
  ## Get host of request.
  return request.headers["Host"]


proc ip*(request: Request): string =
  ## Get IP of request.
  result = request.headers["X-Forwarded-For"]
  if result == "":
    result = request.remoteAddress
  return result


proc path*(request: Request): string =
  ## Get path of request.
  if "?" notin request.uri:
    return request.uri
  return request.uri.split("?")[0]


proc query*(request: Request): string =
  ## Get query of request.
  if "?" notin request.uri:
    return ""
  return request.uri.split("?")[1]


proc reqMethod*(request: Request): HttpMethod =
  ## Get method of request.
  case request.httpMethod
  of "GET":
    return HttpGet
  of "POST":
    return HttpPost
  of "PUT":
    return HttpPut
  of "DELETE":
    return HttpDelete
  of "HEAD":
    return HttpHead
  of "TRACE":
    return HttpTrace
  of "OPTIONS":
    return HttpOptions
  of "CONNECT":
    return HttpConnect
  of "PATCH":
    return HttpPatch
  else:
    return HttpGet


proc multipart*(request: Request): seq[MultipartEntry] =
  ## Get multipart.
  try:
    request.decodeMultipart()
  except:
    @[]


proc secure*(request: Request): bool =
  ## Check if request is secure.
  case request.headers["X-Forwarded-Proto"]
  of "https":
    return true
  else:
    return false


#
# Headers
#
proc hasKey*(headers: HttpHeaders, key: string): bool =
  return headers.contains(key)


template setHeader*(field, value: string) =
  ## Set header of response.
  headers[field] = value



#
# Send file
#
template sendFile*(path: string) =
  let r = readFile(path)
  when declared(headers):
    setHeader("Content-Type", newMimetypes().getMimetype(path.split(".")[^1]))
    request.respond(200, headers, r)
  else:
    request.respond(200, @[("Content-Type", newMimetypes().getMimetype(path.split(".")[^1]))], r)
  return





