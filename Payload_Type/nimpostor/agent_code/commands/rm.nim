import asyncdispatch
from os import tryRemoveFile

proc execute*(path: string): Future[bool] {.async.} =
    result = tryRemoveFile(path)
