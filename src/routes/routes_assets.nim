


import
  std/[
    locks,
    mimetypes,
    os,
    strutils,
    tables
  ]


import
  mummy, mummy/routers,
  mummy_utils


import
  ../utils/assets


var assetRouter*: Router

assetRouter.get("/assets/**",
proc(request: Request) =
  let path = request.path

  acquire(gFilecacheLock)

  if path notin approvedPaths:
    release(gFilecacheLock)
    resp Http404

  var headers: HttpHeaders
  {.gcsafe.}:
    headers["Content-Type"] = m.getMimetype(assets[path].ext)
    request.respond(200, headers, assets[path].filedata)

  release(gFilecacheLock)

  return
)


