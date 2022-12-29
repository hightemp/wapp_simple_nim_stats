import asyncdispatch, httpcore, strutils, strformat, os
import std/json
import std/jsonutils
import std/tables
import times
import fastkiss
import system/ansi_c
import std/db_sqlite
import std/tempfiles

putEnv("PORT", getEnv("PORT", "9000"))
putEnv("DB_HOST", getEnv("DB_HOST", "./wapp_simple_nim_stats.db"))

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

const HTML_STAT_BEGIN = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Statistics</title>
</head>
<body>
    <div class="stat-table">
        <div class="raw-header">
            <div class="cell">Дата</div>
            <div class="cell">Виз.</div>
            <div class="cell">График</div>
        </div>    
"""

const HTML_STAT_END = """
    </div>
<style>
.stat-table { border-bottom: 1px solid rgba(0,0,0,0.1); border-right: 1px solid rgba(0,0,0,0.1); }
.raw-header, .raw {
    display: grid;
    grid-template-columns: 120px 60px 1fr;
}
.raw-header .cell {
    font-weight: bold;
    background: #eee;
}
.cell-bar, .cell { border-top: 1px solid rgba(0,0,0,0.1); border-left: 1px solid rgba(0,0,0,0.1); }
.cell-bar { display: flex; }
.cell { padding: 5px; }
.bar {
    border: 1px solid rgba(0,0,0,0.1);
    background: red;
    height: 100%;
    display: inline-block;
}
</style>
</body>
</html>
"""

const HTML_STAT_BEGIN2 = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Statistics</title>
</head>
<body>
    <div class="stat-table">
        <div class="raw-header">
            <div class="cell">Дата</div>
            <div class="cell">IP</div>
            <div class="cell">JSON</div>
        </div>    
"""

const HTML_STAT_END2 = """
    </div>
<style>
.stat-table { border-bottom: 1px solid rgba(0,0,0,0.1); border-right: 1px solid rgba(0,0,0,0.1); }
.raw-header, .raw {
    display: grid;
    grid-template-columns: 120px 60px 1fr;
}
.raw-header .cell {
    font-weight: bold;
    background: #eee;
}
.cell { border-top: 1px solid rgba(0,0,0,0.1); border-left: 1px solid rgba(0,0,0,0.1); }
.cell { padding: 5px; }
</style>
</body>
</html>
"""

iterator `...`*[T](a: T, b: T): T =
    var res: T = a
    while res <= b:
        yield res
        inc res

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

proc getStatisticsFullSelf(req: Request) {.async.}  =
    var sHTML = "ERROR"
    try:
        sHTML = HTML_STAT_BEGIN2
        var sDBFile = getEnv("DB_HOST")
        var db = open(sDBFile, "", "", "")

        for aRow in db.fastRows(sql"SELECT strftime('%Y-%m-%d',timestamp) as d, ip, json FROM visitors ORDER BY timestamp"):
            sHTML = sHTML & fmt"""
                <div class="raw">
                    <div class="cell">{aRow[0]}</div>
                    <div class="cell">{aRow[1]}</div>
                    <div class="cell">{aRow[2]}</div>
                </div>
            """

        sHTML = sHTML & HTML_STAT_END2
    except CatchableError as e:
        echo "ERROR: " & e.msg
    sHTML.resp

proc getStatisticsSelf(req: Request) {.async.}  =
    var sHTML = "ERROR"
    try:
        sHTML = HTML_STAT_BEGIN
        var sDBFile = getEnv("DB_HOST")
        var db = open(sDBFile, "", "", "")

        for aRow in db.fastRows(sql"SELECT COUNT(id) AS c, strftime('%Y-%m-%d',timestamp) AS dd, strftime('%d',timestamp) AS d FROM visitors GROUP BY strftime('%d',timestamp) ORDER BY timestamp DESC LIMIT 10"):
            var iP = int(parseInt(aRow[0])/1000)*100
            sHTML = sHTML & fmt"""
    <div class="raw">
        <div class="cell">{aRow[1]}</div>
        <div class="cell">{aRow[0]}</div>
        <div class="cell-bar">
            <div class="bar" style="width:{iP}%"></div>
        </div>
    </div>
"""

        sHTML = sHTML & HTML_STAT_END
    except CatchableError as e:
        echo "ERROR: " & e.msg
    sHTML.resp

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
    # app.get("/mp4", getCounterMP4)
    app.get("/statstics_self", getStatisticsSelf)
    app.get("/statstics_self_full", getStatisticsFullSelf)

    app.run()

main()

