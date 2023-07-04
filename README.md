![Nimpostor](agent_icons/nimpostor.svg)

Nimpostor is a cross-platform (Linux & Windows) implant written in Nim as a fun project to learn about Nim and see what it can bring to the table for red team tool development. It is base of [Nimplant](https://github.com/MythicAgents/Nimplan) and developed a little further. Currently, the public part of Nimpostor lacks extensive evasive tradecraft; however, this is being left open as a challenge for the reader.


## Installation
To install Nimpostor, you'll need Mythic installed on a remote computer. You can find installation instructions for Mythic at the [Mythic project page](https://github.com/its-a-feature/Mythic/).

From the Mythic install root, run the command:

`./install_agent_from_github.sh https://github.com/sec-consult/Nimpostor`

Once installed, restart Mythic to build a new agent.


### Highlighted Agent Features
- Cross-platform
- Fully asynchronous
- Can generate agents compiled from both C and C++ source code
- Can generate agent as shellcode
- Execute_Assembly functionality

## Commands Manual Quick Reference

Command | Syntax | Description
------- | ------ | -----------
cat | `cat [file]` | Retrieve the output of a file.
cd | `cd [dir]` | Change working directory.
cp | `cp [source] [destination]` | Copy a file from source to destination. Modal popup.
curl | `curl [url] [method] [headers] [body]` | Execute a single web request.
download | `download [path]` | Download a file off the target system.
execute_assembly | `execute_assembly [file]` | Loads a .NET file into memory and executes it.
exit | `exit` | Exit a callback.
getav | `getav` | Get installed antivirus programs.
getenv | `getenv` | Get all of the current environment variables.
jobs | `jobs` | List all running jobs.
kill | `kill [pid]` | Attempt to kill the process specified by `[pid]`.
ls | `ls [path] [recurse]` | List files and folders in `[path]` with optional param to list recursively. Defaults to current working directory.
mkdir | `mkdir [dir]` | Create a directory.
mv | `mv [source] [destination]` | Move a file from source to destination. Modal popup.
ps | `ps` | List process information.
pwd | `pwd` | Print working directory.
rm | `rm [path]` | Remove a file specified by `[path]`
shell | `shell [command]` | Run a shell command which will translate to a process being spawned with command line: `cmd.exe /r[command]`
unsetenv | `setenv [envname] [value]` | Sets an environment variable to your choosing.
sleep | `sleep [seconds]` | Set the callback interval of the agent in seconds.
unsetenv | `unsetenv [envname]` | Unset an environment variable.
upload | `upload` | Upload a file to a remote path on the machine. Modal popup.

## Supported C2 Profiles

Currently, only one C2 profile is available to use when creating a new Nimpostor agent: HTTP.

### HTTP Profile

The HTTP profile calls back to the Mythic server over the basic, non-dynamic profile. When selecting options to be stamped into Nimpostor at compile time, all options are respected with the exception of those parameters relating to GET requests.

</br>

*More coming soon!*

### Roadmap
- [] Implement functionality to execute BOFs
- [] Integration of a socks proxy
- [] P2P communication between agents
- [] Remote process injection capabilities

