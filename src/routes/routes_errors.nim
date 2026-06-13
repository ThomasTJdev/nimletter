
import
  std/[
    strutils
  ]


import
  mummy,
  mummy_utils




proc routeCustom404*(request: Request) =
  ## This is a custom 404 handler

  var headers: httpheaders.HttpHeaders

  case request.reqMethod
  of HttpPost, HttpDelete, HttpHead:
    setHeader("Content-Type", $ContentType.Text)
    request.respond(404, headers)
  of HttpGet:
    setHeader("Content-Type", $ContentType.Html)
    request.respond(404, headers, "404")
  else:
    setHeader("Content-Type", $ContentType.Text)
    request.respond(404, headers)
  return


proc routeErrorHandler*(request: Request, e: ref Exception) =
  ## Handles unhandled exceptions from route handlers.
  ## IMPORTANT: must never throw itself - any exception here leaves the client
  ## with a bare TCP-level error (no HTTP response at all).

  var data: seq[(string, string)]
  for v in request.queryParams:
    data.add((v[0], v[1]))

  for v in request.pathParams:
    data.add((v[0], v[1]))

  data.add(("remote_addr", request.ip))
  data.add(("request_uri", request.path))
  data.add(("error", if e != nil: e.msg else: "unknown"))

  echo data

  #
  # Pretty page for browsers
  #
  let acceptHeader = try: request.headers["Accept"] except: ""
  if request.reqMethod == HttpGet and acceptHeader.startsWith("text/html"):
    var headers: httpheaders.HttpHeaders
    setHeader("Content-Type", $ContentType.Html)
    request.respond(502, headers, "502")
    return

  #
  # Plain text for API / webhook callers
  #
  var headers: httpheaders.HttpHeaders
  setHeader("Content-Type", $ContentType.Text)
  request.respond(502, headers, "We hit a problem. An error ticket has been made and sent to the developers.")
  return

