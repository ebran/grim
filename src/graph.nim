import json
import tables
import oids
import strformat

export json
export tables

type
  Edge = ref object
    oid*: string
    label*: string
    startsAt: Node
    endsAt: Node
    properties*: JsonNode

  Node = ref object
    oid*: string
    label*: string
    properties*: JsonNode
    adj: Table[string, Edge]

  Graph = ref object
    name*: string
    nodes*: Table[string, Node]
    edges*: Table[string, Edge]

proc `$`*(g: Graph): string =
  result = fmt"I am {g.name}!"

proc `$`*(n: Node): string =
  result = fmt"<Node {n.oid} ({n.label}): {n.properties}>"

proc `$`*(e: Edge): string =
  result = fmt"<Edge {e.oid}: {e.startsAt.oid} -- {e.label} {e.properties} --> {e.endsAt.oid}>"

proc `%`(t: tuple): JsonNode =
  ## Quick wrapper around the generic JObject constructor.
  var propertyList: seq[tuple[key: string, val: JsonNode]] = @[]
  for prop, val in t.fieldPairs:
    propertyList.add((prop, %val))
  result = %propertyList

proc contains*(self: Graph, key: string): bool =
  ## Check if node oid is in Graph
  result = key in self.nodes or key in self.edges

proc contains*(self: Graph, key: Node): bool =
  ## Check if node object is in Graph
  result = key.oid in self.nodes or key.oid in self.edges

proc newGraph*(name: string = "graph"): Graph =
  ## Create empty graph
  new result
  result.name = name

proc newNode*(label: string, properties: tuple = (),
    ident: string = ""): Node =
  ## Create a new Node
  new result

  result.label = label
  result.properties = %properties

  # Generate oid
  let oid =
    if ident.len == 0:
      $genOid()
    else:
      ident

  result.oid = oid

proc newEdge*(A: Node, B: Node, label: string, properties: tuple = (),
  ident: string = ""): Edge =
  ## Create a new Edge
  new result

  result.startsAt = A
  result.endsAt = B
  result.label = label
  result.properties = %properties

  # Generate oid
  let oid =
    if ident.len == 0:
      $genOid()
    else:
      ident

  result.oid = oid

proc addNode*(self: var Graph, label: string, props: tuple = (),
    ident: string = ""): string =
  ## Add node to Graph
  let n = newNode(label, properties = props, ident = ident)
  self.nodes[n.oid] = n
  result = n.oid

proc addNode*(self: var Graph, n: Node, props: tuple = ()): string =
  ## Add node to Graph.  TODO: Update properties
  self.nodes[n.oid] = n
  result = n.oid

proc addEdge*(self: var Graph, A: Node, B: Node, label: string,
    props: tuple = (), ident: string = ""): string =
  ## Add edge to Graph TODO: Update properties
  # Add nodes to graph if not already there
  let idA =
    if A in self:
      A.oid
    else:
      self.addNode(A)
  let idB =
    if B in self:
      B.oid
    else:
      self.addNode(B)

  let e = newEdge(A, B, label, properties = props, ident = ident)
  self.nodes[A.oid].adj.add(B.oid, e)

  result = e.oid

proc addEdge*(self: var Graph, A: string, B: string, label: string,
  props: tuple = (), ident: string = ""): string =
  ## Add edge to Graph TODO: Update properties

  let e = newEdge(self.nodes[A], self.nodes[B], label, properties = props, ident = ident)
  self.nodes[A].adj.add(B, e)
  self.edges[e.oid] = e

  result = e.oid

proc numberOfNodes*(self: Graph): int =
  ## Return number of nodes in Graph
  result = self.nodes.len

proc numberOfEdges*(self: Graph): int =
  ## Return number of edges in Graph
  result = self.edges.len

proc hasEdge*(self: var Graph, A: string, B: string): bool =
  result = A in self.nodes and B in self.nodes[A].adj

when isMainModule:
  var g = newGraph("People")
  let oid = g.addNode("Person")

  # check oid in g
  # check g.nodes[oid].label == "Person"
  # check g.numberOfNodes == 1
  # check g.numberOfEdges == 0
