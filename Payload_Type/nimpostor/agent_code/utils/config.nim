from random import randomize, rand
from strutils import parseInt, parseBool

type
    Server* = object 
       Domain*: string
       Count*: int

type
    Config* = object
       CallBackHosts*: seq[string]
       Servers*: seq[Server]
       PayloadUUID*: string
       UUID*: string
       UserAgent*: string
       HostHeader*: string
       Sleep*: int
       Jitter*: int
       KillDate*: string
       Param*: string
       ChunkSize*: int
       DefaultProxy*: bool
       ProxyAddress*: string
       ProxyUser*: string
       ProxyPassword*: string
       GetUrl*: string
       PostUrl*: string
       Psk*: string

proc createConfig*() : Config =
    # Check if compile time defined pragma (PSK) is definde
    # If defined will be "AESPSK"
    # --d:psk=42
    const AESPSK = ""
    var temp = Config(
        CallBackHosts: @["callback_host:callback_port"],
        PayloadUUID: "payload_uuid",
        UserAgent: "USER_AGENT",
        HostHeader: "domain_front",
        Param: "query_path_name",
        ChunkSize: parseInt("512000"),
        DefaultProxy: parseBool("false"),
        ProxyAddress: "proxy_host:proxy_port",
        ProxyUser: "proxy_user",
        ProxyPassword: "proxy_pass",
        Sleep: parseInt("2"),
        Jitter: parseInt("0"),
        KillDate: "killdate",
        GetUrl: "/get_uri",
        PostUrl: "/post_uri",
        Psk: AESPSK
    )

    for host in temp.CallBackHosts:
        temp.Servers.add(Server(Domain: host, Count: 0))
    result = temp

proc serverCmp*(x, y: Server): int =
    # custom sorting cmp proc for Server objects
    # don't think i need this for now
    let tone = x.Count
    let ttwo = y.Count
    if tone < ttwo: -1
    elif tone == ttwo: 0
    else: 1

proc genSleepTime*(config: Config): float =
    randomize()
    let temp = config.Jitter / 100
    let sleepTime = float(config.Sleep)
    let slow = float(sleepTime - (sleepTime * temp))
    let shigh = float(sleepTime + (sleepTime * temp))
    let dwell = rand(slow..shigh)
    result = dwell * 1000
