
import
  std/[
    locks,
    mimetypes,
    os,
    tables
  ]


var gFilecacheLock*: Lock
initLock(gFilecacheLock)


proc embed(directory: string): Table[string, tuple[filedata: string, ext: string]] =
  echo "Embedding assets from " & directory
  for fd in walkDirRec(directory, checkDir = true):
    result["/" & fd] = (staticRead("../../" & fd), splitFile(fd).ext)
    echo fd
  return result

proc pathCheck(assets: Table[string, tuple[filedata: string, ext: string]]): seq[string] =
  for path in assets.keys():
    result.add(path)
  return result

const assets* = embed("assets")
const approvedPaths* = pathCheck(assets)
let m* = newMimetypes()
