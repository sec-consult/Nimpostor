# Get installed AV 
import asyncdispatch
import winim/com

proc execute*(): Future[string] {.async.} =
    var av = ""
    var wmi = GetObject(r"winmgmts:{impersonationLevel=impersonate}!\\.\root\securitycenter2")
    for i in wmi.execQuery("SELECT displayName FROM AntiVirusProduct"):
        av = av & "\n[+] " & $(i.displayName)
    result = av
