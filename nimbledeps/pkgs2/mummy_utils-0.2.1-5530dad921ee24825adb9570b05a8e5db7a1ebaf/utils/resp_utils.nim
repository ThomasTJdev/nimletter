# Copyright Thomas T. Jarløv (TTJ) - ttj@ttj.dk

{.push raises: [].}

import std/[json, strutils]

import
  mummy,
  mummy/routers

import std/httpcore except HttpHeaders

type
  ContentType* = enum
    Json = "application/json"
    Text = "text/plain"
    Html = "text/html; charset=utf-8"

#
# General response
#
template resp*(
    httpStatus: HttpCode = Http200,
    headers: HttpHeaders,
    body: string
  ) =
  when defined(dev):
    if headers["Content-Type"] == "":
      echo "Warning: No Content-Type set in response, defaulting to " & $ContentType.Html

  request.respond(httpStatus.ord, headers, body)
  return


template resp*(
    body: string,
    contentType = $ContentType.Html
  ) =
  ## Returns with text/html as default.
  when declared(headers):
    setHeader("Content-Type", $contentType)
    request.respond(200, headers, body)
  else:
    request.respond(200, @[("Content-Type", contentType)], body)
  return


template resp*(
    httpStatus: HttpCode,
  ) =
  ## Returns response code with empty headers and body.
  request.respond(httpStatus.ord, emptyHttpHeaders(), "")
  return


template resp*(
    httpStatus: HttpCode,
    body: string
  ) =
  when declared(headers):
    if not headers.contains("Content-Type"):
      setHeader("Content-Type", $ContentType.Html)
    request.respond(httpStatus.ord, headers, body)
  else:
    request.respond(httpStatus.ord, @[("Content-Type", $ContentType.Html)], body)
  return


template resp*(
    httpStatus: HttpCode,
    contentType: ContentType,
    body: string
  ) =
  when declared(headers):
    setHeader("Content-Type", $contentType)
    request.respond(httpStatus.ord, headers, body)
  else:
    request.respond(httpStatus.ord, @[("Content-Type", $contentType)], body)
  return


#
# Json response
#
template resp*(body: JsonNode) =
  when declared(headers):
    setHeader("Content-Type", $ContentType.Json)
    request.respond(200, headers, $body)
  else:
    request.respond(200, @[("Content-Type", $ContentType.Json)], $body)
  return


template resp*(httpStatus: HttpCode, contentType: ContentType, body: JsonNode) =
  request.respond(httpStatus.ord, @[("Content-Type", $contentType)], $body)
  return


template resp*(httpStatus: HttpCode, body: JsonNode) =
  request.respond(httpStatus.ord, @[("Content-Type", $ContentType.Json)], $body)
  return


#
# Redirects
#
template redirect*(path: string) =
  when declared(headers):
    headers["Location"] = path
    request.respond(303, headers)
  else:
    request.respond(303, @[("Location", path)])
  return

template redirect*(httpStatus: HttpCode, path: string) =
  when declared(headers):
    headers["Location"] = path
    request.respond(httpStatus.ord, headers)
  else:
    request.respond(httpStatus.ord, @[("Location", path)])
  return

template redirect*(httpStatus: HttpCode, headers: HttpHeaders, path: string) =
  headers["Location"] = path
  request.respond(httpStatus.ord, headers)
  return
