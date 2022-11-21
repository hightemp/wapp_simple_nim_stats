import asyncnet, asyncdispatch, httpcore, strutils, strformat, os
import std/json
import std/jsonutils
import std/envvars
# import norm/[model, sqlite, pragmas]
import std/tables
import times
import fastkiss
import sugar
import system/ansi_c
import std/[db_sqlite, math]

putEnv("PORT", getEnv("PORT", "9000"))
putEnv("DB_HOST", getEnv("DB_HOST", "./db.sqlite.db"))
putEnv("REMOTE_ADDR", getEnv("REMOTE_ADDR", "0.0.0.0"))

# type
#     HTTPRequest* = ref object of Model
#         date* {.unique.}: DateTime
#         ip*: string
#         env*: string

# func newHTTPRequest*(date:DateTime, ip:string, env:string): HTTPRequest =
#     HTTPRequest(date: date, ip: ip, env: env)

var iPort = getEnv("PORT").parseInt()

proc fnGetEnv(): Table[string, string] {.inline.} =
    var aEnv = initTable[string, string]()

    for sK,sV in envPairs():
        aEnv[sK] = sV

    return aEnv

# discard await 

proc getCounter(req: Request) {.async.}  =
    try:
        # var db = getDb()

        req.response.headers["content-type"] = "image/svg+xml; charset=utf-8"
        req.response.headers["cache-control"] = "max-age=0, no-cache, no-store, must-revalidate"
        req.response.statusCode = Http200

        var aEnv = fnGetEnv()
        var sEnv = $(aEnv.toJson)
        echo "ENV: ", sEnv

        var iC: int64 = 0

        var iDateTime = getTime().toUnix
        var sRemoteAddr = aEnv["REMOTE_ADDR"]

        echo "[", getTime().utc, "][", sRemoteAddr , "] ", req.reqMethod

        # var oHTTPRequest = newHTTPRequest(iDateTime, sRemoteAddr, sEnv)

        var sDBFile = getEnv("DB_HOST")
        var db = open(sDBFile, "", "", "")

        db.exec(sql"""CREATE TABLE IF NOT EXISTS visitors (
                        id    INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp INTEGER NOT NULL,
                        ip VARCHAR(50) NOT NULL,
                        env_json VARCHAR(4000) NOT NULL
                    )""")

        db.exec(sql"INSERT INTO visitors (timestamp, ip, env_json) VALUES (?, ?, ?)", 
            $iDateTime, sRemoteAddr, sEnv)

        # db.createTables(oHTTPRequest)
        # db.insert(oHTTPRequest)

        # iC = db.count(HTTPRequest)

        iC = db.getValue(sql"SELECT COUNT(*) AS cnt FROM visitors").parseInt()

        var sSVG = """
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="110" height="20" role="img" aria-label="statistics: {NUMBER}">
    <title>statistics: {NUMBER}</title>
    <linearGradient id="s" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1" />
        <stop offset="1" stop-opacity=".1" />
    </linearGradient>
    <clipPath id="r">
        <rect width="110" height="20" rx="3" fill="#fff" />
    </clipPath>
    <g clip-path="url(#r)">
        <rect width="59" height="20" fill="#555" />
        <rect x="59" width="51" height="20" fill="#a4a61d" />
        <rect width="110" height="20" fill="url(#s)" />
    </g>
    <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
        <text aria-hidden="true" x="305" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="490">statistics</text>
        <text x="305" y="140" transform="scale(.1)" fill="#fff" textLength="490">statistics</text>
        <text aria-hidden="true" x="835" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="410">{NUMBER}</text>
        <text x="835" y="140" transform="scale(.1)" fill="#fff" textLength="410">{NUMBER}</text>
    </g>
</svg>
    """

        var sC = $iC
        var sFormat = "000000"
        var sNumber = sFormat[0..(sFormat.len - sC.len - 1)] & sC

        sSVG = sSVG.replace("{NUMBER}", sNumber)
        # return req.resp(sSVG)
        sSVG.resp
    except:
        echo "ERROR"
        "ERROR".resp

proc main() =
    let app = newApp()
    app.config.port = iPort

    addSignal(SIGINT, proc(fd: AsyncFD): bool =
        # asyncCheck 
        # close db
        app.close()
        echo "App shutdown completed! Bye-Bye Kisses :)"
        quit(QuitSuccess)
    )

    app.get("/", getCounter)

    app.run()

main()

