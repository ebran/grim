import os
import json
import strutils
import uri
import httpclient
import base64
import grim

type
  Neo4j* = object
    client: HttpClient
    address: string
    auth: (string, string)

proc getEnvOrRaise(env: string): string =
  if not os.existsEnv(env):
    raise newException(ValueError, "Environment variable $1 is not defined.".format(env))
  result = os.getEnv(env)

proc initNeo4j(hostname: string, auth: (string, string)): Neo4j =
  var client = newHttpClient()
  client.headers["Authorization"] = "Basic " & base64.encode(auth[0] & ":" & auth[1])
  result = Neo4j(client: client, address: hostname, auth: auth)

proc beginCommit(db: Neo4j, statement: string): Response =
  let
    # HTTP request
    req = %*{
      "statements": [
        {
        "statement": "MATCH (n)-[r]-() RETURN n,r",
        "resultDataContents": ["graph"]
        }
      ]
    }
    # HTTP response
    resp = db.client.post(db.address, body = $req)

  result = resp

proc dump(db: Neo4j): Graph =
  let r = db.beginCommit("MATCH ()-[r]-() RETURN r")
  echo r.version, ", ", r.status, ", ", r.headers #, ", ", r.body
  result = newGraph()

when isMainModule:
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

  var
    db = initNeo4j($resource, auth = (user, password))
    g = db.dump()

  echo g

  # var data = %*{
  #   "statements": [ {"statement": "MATCH (n) RETURN n"}]
  # }

  # let resp = client.post($resource, body = $data)
  # echo resp.body
