# Given a file path read the contents
import asyncdispatch, asyncfile

proc execute*(path: string): Future[string] {.async.} =
    try:
      var fh = openAsync(path, fmRead)
      let file = await fh.readAll()
      result = file
      fh.close()
    except:
      let
        e = getCurrentException()
        msg = getCurrentExceptionMsg()
      echo "Got exception ", repr(e), " with message ", msg
      echo $(path)
