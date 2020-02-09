import os
import json
import strutils
import uri
import httpclient
import base64
import grim

proc getEnvOrRaise(env: string): string =
  if not os.existsEnv(env):
    raise newException(ValueError, "Environment variable $1 is not defined.".format(env))
  result = os.getEnv(env)

let
  user = getEnvOrRaise("NEO4J_USER")
  password = getEnvOrRaise("NEO4J_PASSWORD")
  hostname = getEnvOrRaise("NEO4J_HOSTNAME")

  resource = Uri(
    scheme: "http",
    hostname: hostname,
    port: "7474",
    path: "db/data/transaction/commit"
  )

var client = newHttpClient()
client.headers["Authorization"] = "Basic " & base64.encode(user & ":" & password)

when isMainModule:
  var data = %*{
    "statements": [ {"statement": "MATCH (n) RETURN n"}]
  }

  let resp = client.post($resource, body = $data)
  echo resp.body
