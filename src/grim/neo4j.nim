# stdlib imports
import json
import strutils
import uri
import httpclient
import base64

# grim import
import grim

# re-export grim
export grim

type
  ## Client for connecting to Neo4j database
  Neo4jClient* = object
    httpClient: HttpClient
    hostname: string
    scheme: string
    port: int
    resource: string

proc initNeo4jClient*(hostname: string, scheme: string = "http",
    port: int = 7474, resource: string = "data", auth: (string,
        string)): Neo4jClient =
  ## Initialize a new Neo4j client
  # Init the HTTP client with simple user/password authorization
  var client = newHttpClient()
  client.headers["Authorization"] = "Basic " & base64.encode(auth[0] & ":" & auth[1])
  result = Neo4jClient(httpClient: client, resource: resource,
      hostname: hostname, scheme: scheme, port: port)

proc endpoint(client: Neo4jClient): string =
  ## Return common prefix to transaction endpoint for `client`.
  let address = Uri(
    scheme: client.scheme,
    hostname: client.hostname,
    port: $client.port,
    path: "db/$1/transaction/commit".format(client.resource)
    )

  result = $address

proc beginCommit(client: Neo4jClient, statement: string): JsonNode =
  ## Begin and auto-commit transaction to Neo4j database.
  let
    # Setup body for Cypher HTTP request
    req = %*{
      "statements": [
        {
          "statement": statement,
          "resultDataContents": ["graph"]
        }
      ]
    }
    # Get HTTP response
    resp = client.httpClient.post(client.endpoint, body = $req)

  # Check status and return body as json when successful
  case resp.status:
    of $Http200:
      result = parseJson(resp.body)["results"][0]["data"]
    else:
      raise newException(ValueError, "Unknown response '$1' from server.".format(resp.status))

proc execute*(client: Neo4jClient, query: string): Graph =
  ## Execute Cypher `query` on the remote database.
  result = newGraph()

  # Iterate over all nodes and relationships
  for elem in client.beginCommit(query):
    # Add nodes
    for node in elem["graph"]["nodes"]:
      let
        label = node["labels"][0].getStr
        data = node["data"].toTable
        oid = node["id"].getStr
      discard result.addNode(label, data, oid)

    # Add relationships between nodes
    for rel in elem["graph"]["relationships"]:
      let
        startsAt = rel["startNode"].getStr
        endsAt = rel["endNode"].getStr
        label = rel["type"].getStr
        data = rel["data"].toTable
        oid = rel["id"].getStr
      discard result.addEdge(startsAt, endsAt, label, data, oid)

proc dump*(client: Neo4jClient, name: string = "graph"): Graph =
  ## Dump Neo4j database as a labeled property graph (LPG).
  result = client.execute("MATCH (n)-[r]-() RETURN n,r")
