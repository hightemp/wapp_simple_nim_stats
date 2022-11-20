import asyncnet, asyncdispatch, httpcore, strutils, strformat, os
import std/strformat
import std/strtabs
import std/json
import std/jsonutils
import std/envvars
import strutils
import norm/[model, sqlite, pragmas]
import std/tables
import times, os

import fastkiss
from fastkiss/utils import decodeData
import regex
from strformat import `&`

putEnv("PORT", getEnv("PORT", "9000"))
putEnv("DB_HOST", getEnv("DB_HOST", "./db.sqlite.db"))
putEnv("REMOTE_ADDR", getEnv("REMOTE_ADDR", "0.0.0.0"))

type
    HTTPRequest* = ref object of Model
        date* {.unique.}: DateTime
        ip*: string
        env*: string

func newHTTPRequest*(date:DateTime, ip:string, env:string): HTTPRequest =
    HTTPRequest(date: date, ip: ip, env: env)

var aEnv = initTable[string, string]()

for sK,sV in envPairs():
    aEnv[sK] = sV

let db = getDb()

var iDateTime = now().utc
var sRemoteAddr = aEnv["REMOTE_ADDR"]
var sJSON = $(aEnv.toJson)
var oHTTPRequest = newHTTPRequest(iDateTime, sRemoteAddr, sJSON)

db.createTables(oHTTPRequest)
db.insert(oHTTPRequest)
var iC = db.count(HTTPRequest)

var iPort = getEnv("PORT").parseInt()

proc main() =
    let app = newApp()
    app.config.port = iPort

    app.get("*", proc (req: Request) {.async.} =
        echo "REQUEST: ", req.reqMethod, " ", req.url

        req.response.headers["content-type"] = "image/svg+xml; charset=utf-8"
        req.response.statusCode = Http200

        var sSVG = readFile("./badge.svg")
        sSVG = sSVG.replace("{NUMBER}", $iC)
        # await respond sSVG
        await req.respond(sSVG)
    )

    app.run()

main()

