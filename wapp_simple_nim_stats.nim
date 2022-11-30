import asyncnet, asyncdispatch, httpcore, strutils, strformat, os
import std/json
import std/jsonutils
import std/envvars
import std/tables
import times
import fastkiss
import sugar
import system/ansi_c
import std/[db_sqlite, math]
import std/tempfiles

putEnv("PORT", getEnv("PORT", "9000"))
putEnv("DB_HOST", getEnv("DB_HOST", "./db.sqlite.db"))

var iPort = getEnv("PORT").parseInt()

const SVG_TEXT = """
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

proc getCounter(req: Request) {.async.}  =
    try:
        req.response.headers["content-type"] = "image/svg+xml; charset=utf-8"
        req.response.headers["cache-control"] = "max-age=0, no-cache, no-store, must-revalidate"
        req.response.statusCode = Http200

        var sJson = $(req.headers.toJson)
                                
        var iC: int64 = 0

        var iDateTime = getTime().toUnix
        var sRemoteAddr = req.headers["remote_addr"]

        echo "[", getTime().utc, "][", sRemoteAddr , "] ", req.reqMethod
        
        var sDBFile = getEnv("DB_HOST")
        var db = open(sDBFile, "", "", "")

        db.exec(sql"""CREATE TABLE IF NOT EXISTS visitors (
                        id    INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp INTEGER NOT NULL,
                        ip VARCHAR(50) NOT NULL,
                        json VARCHAR(4000) NOT NULL
                    )""")

        db.exec(sql"INSERT INTO visitors (timestamp, ip, json) VALUES (?, ?, ?)", 
            $iDateTime, sRemoteAddr, sJson)
        
        iC = db.getValue(sql"SELECT COUNT(*) AS cnt FROM visitors").parseInt()

        var sC = $iC
        var sFormat = "000000"
        var sNumber = sFormat[0..(sFormat.len - sC.len - 1)] & sC

        var sCounterSVG = SVG_TEXT.replace("{NUMBER}", sNumber)
        sCounterSVG.resp
    except CatchableError as e:
        echo "ERROR: " & e.msg
        "ERROR".resp

proc getCounterMP4(req: Request) {.async.}  =
    try:
        req.response.headers["content-type"] = "video/mp4; charset=utf-8"
        req.response.headers["cache-control"] = "max-age=0, no-cache, no-store, must-revalidate"
        req.response.statusCode = Http200

        var sJson = $(req.headers.toJson)
                                
        var iC: int64 = 0

        var iDateTime = getTime().toUnix
        var sRemoteAddr = req.headers["remote_addr"]

        echo "[", getTime().utc, "][", sRemoteAddr , "] ", req.reqMethod
        
        var sDBFile = getEnv("DB_HOST")
        var db = open(sDBFile, "", "", "")

        db.exec(sql"""CREATE TABLE IF NOT EXISTS visitors (
                        id    INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp INTEGER NOT NULL,
                        ip VARCHAR(50) NOT NULL,
                        json VARCHAR(4000) NOT NULL
                    )""")

        db.exec(sql"INSERT INTO visitors (timestamp, ip, json) VALUES (?, ?, ?)", 
            $iDateTime, sRemoteAddr, sJson)
        
        iC = db.getValue(sql"SELECT COUNT(*) AS cnt FROM visitors").parseInt()

        var sC = $iC
        var sFormat = "000000"
        var sNumber = sFormat[0..(sFormat.len - sC.len - 1)] & sC

        var sCounterSVG = SVG_TEXT.replace("{NUMBER}", sNumber)

        let (oFile, sFileName) = createTempFile("tmpprefix_", "_end.svg")
        oFile.write(sCounterSVG)
        oFile.close()
        
        var sSVGFilePath = sFileName
        var sMP4FilePath = sFileName.replace(".svg", ".mp4")

        var iECode = execShellCmd(&"ffmpeg -i {sSVGFilePath} {sMP4FilePath}")

        if iECode>0:
            raise newException(ValueError, "It won't compile")

        readFile(sMP4FilePath).resp
        
    except CatchableError as e:
        echo "ERROR: " & e.msg
        "ERROR".resp

proc main() =
    let app = newApp()
    app.config.port = iPort

    addSignal(SIGINT, proc(fd: AsyncFD): bool =
        app.close()
        echo "App shutdown completed! Bye-Bye Kisses :)"
        quit(QuitSuccess)
    )

    app.get("/", getCounter)
    app.get("/mp4", getCounterMP4)

    app.run()

main()

