# Copyright Thomas T. Jarløv (TTJ) - ttj@ttj.dk

{.push raises: [].}

import std/[strutils, strtabs]

import
  mummy,
  mummy/routers,
  mummy/multipart

from webby import decodeQueryComponent, `[]`

template value(s: string): string =
  when defined(caseSensitiveParams):
    s
  else:
    s.toLowerAscii()


#
# Param generator
#
proc paramPath*(request: Request, s: string): string =
  ## Find and return single param from request.
  for p in request.pathParams:
    if p[0].value() == s.value():
      return p[1]
  return ""


proc paramQuery*(request: Request, s: string): string =
  ## Find and return single param from request.
  for p in request.queryParams:
    if p[0].value() == s.value():
      return p[1]
  return ""


proc paramBody*(request: Request, s: string): string =
  ## Find and return single param from request.
  if "x-www-form-urlencoded" in request.headers["Content-Type"].toLowerAscii():
    try:
      for pairStr in request.body.split('&'):
        let
          pair = pairStr.split('=', 1)
          kv =
            if pair.len == 2:
              (decodeQueryComponent(pair[0]), decodeQueryComponent(pair[1]))
            else:
              (decodeQueryComponent(pair[0]), "")

        if kv[0].value() == s.value():
          return kv[1]
    except CatchableError:
      return ""


proc paramGeneratorValue*(request: Request, s: string): string =
  ## Find and return single param from request.
  ##
  ## Starts in:
  ## - URL path
  ## - URL query
  ## - body data.

  # 1. Path
  result = paramPath(request, s)
  if result != "":
    return result

  # 2. Query
  result = paramQuery(request, s)
  if result != "":
    return result

  # 3. Body
  result = paramBody(request, s)



proc paramGenerator*(request: Request): StringTableRef =
  ## Generate params from request.
  ##
  ## Generates all params available in the request.
  ## Starts in:
  ## - body data
  ## - URI query
  ## - URI path

  result = newStringTable(modeCaseInsensitive)

  # Body
  try:
    if "x-www-form-urlencoded" in request.headers["Content-Type"].toLowerAscii():
      for pairStr in request.body.split('&'):
        let
          pair = pairStr.split('=', 1)
          kv =
            if pair.len == 2:
              (decodeQueryComponent(pair[0]), decodeQueryComponent(pair[1]))
            else:
              (decodeQueryComponent(pair[0]), "")

        result[kv[0].value()] = kv[1]

    # Query
    for p in request.queryParams:
      result[p[0].value()] = p[1]

    # Path
    for p in request.pathParams:
      result[p[0].value()] = p[1]
  except CatchableError:
    return result


#
# Param access
#
template params*(request: Request): StringTableRef =
  paramGenerator(request)


template params*(request: Request, s: string): string =
  ## Get params of request.
  paramGeneratorValue(request, s)


template `@`*(s: string): untyped =
  ## Get param.
  paramGeneratorValue(request, s)