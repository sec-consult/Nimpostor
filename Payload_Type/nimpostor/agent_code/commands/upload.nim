# Upload file
import asyncfile, asyncdispatch, os
import base64

proc execute*(contents: string, path: string, ChunkNum: int, ChunkSize: int, TotalChunks: int): Future[string] {.async.} =
    try:
        var strm = openAsync(path, fmAppend)
        #var num = ChunkNum - 1
        #let pos = if fileExists(path): int(getfileSize(path)) else: 0
        #let pos = if num == 0: 0 else: (ChunkSize + ((num - 1) * ChunkSize))
        #echo "Position should be: ", pos
        #echo "Because Filesize is: ", getfileSize(path)
        #strm.setFilePos(pos)
        let decoded = decode(contents)
        await strm.write(decoded)
        strm.close()
        echo "wrote chunk"
        result = "Uploaded file successfully to " & $(path)
    except:
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
        let error = "Failed to upload file: " & msg
        echo error
        result = error
