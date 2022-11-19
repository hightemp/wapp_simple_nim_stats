import std/strformat
import std/[strtabs, cgi]
import std/json
import std/jsonutils
import std/envvars
import strutils
import norm/[model, sqlite, pragmas]
import std/tables
import times, os

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

var sSVG = readFile("./badge.svg")

sSVG = sSVG.replace("{NUMBER}", $iC)

write(stdout, "Content-type: image/svg+xml;charset=utf-8\n\n")

writeLine(stdout, sSVG)
