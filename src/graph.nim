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
  ## Pretty-print Graph
  result = fmt"I am {g.name}!"

proc `$`*(n: Node): string =
  ## Pretty-print Node
  result = fmt"<Node {n.oid} ({n.label}): {n.properties}>"

proc `$`*(e: Edge): string =
  ## Pretty-print Edge
  result = fmt"<Edge {e.oid}: {e.startsAt.oid} -- {e.label} {e.properties} --> {e.endsAt.oid}>"

proc `%`(t: tuple): JsonNode =
  ## Quick wrapper around the generic JObject constructor.
  var propertyList: seq[tuple[key: string, val: JsonNode]] = @[]
  for prop, val in t.fieldPairs:
    propertyList.add((prop, %val))
  result = %propertyList

proc contains*(self: Graph, key: string): bool =
  ## Check if Node or Edge oid is in Graph
  result = key in self.nodes or key in self.edges

proc contains*(self: Graph, key: Node): bool =
  ## Check if Node object is in Graph
  result = key.oid in self.nodes

proc contains*(self: Graph, key: Edge): bool =
  ## Check if Edge object is in Graph
  result = key.oid in self.edges

proc newGraph*(name: string = "graph"): Graph =
  ## Create a new Graph
  new result

  result.name = name

proc newNode*(label: string, properties: tuple = (),
    ident: string = $genOid()): Node =
  ## Create a new Node
  new result

  result.label = label
  result.properties = %properties
  result.oid = ident

proc newEdge*(A: Node, B: Node, label: string, properties: tuple = (),
  ident: string = $genOid()): Edge =
  ## Create a new Edge
  new result

  result.startsAt = A
  result.endsAt = B
  result.label = label
  result.properties = %properties
  result.oid = ident

proc addNode*(self: var Graph, label: string, props: tuple = (),
    ident: string = $genOid()): string =
  ## Add Node to Graph.
  let n = newNode(label, properties = props, ident = ident)

  if n in self:
    return n.oid

  self.nodes[n.oid] = n
  result = n.oid

proc addNode*(self: var Graph, n: Node): string =
  ## Add Node to Graph.
  if n in self:
    return n.oid

  self.nodes[n.oid] = n
  result = n.oid

proc addEdge*(self: var Graph, e: Edge): string =
  ## Add Edge to Graph.
  if e in self:
    return e.oid

  self.nodes[e.startsAt.oid].adj.add(e.endsAt.oid, e)
  self.edges[e.oid] = e


proc addEdge*(self: var Graph, A: Node, B: Node, label: string,
    props: tuple = (), ident: string = $genOid()): string =
  ## Add Edge to Graph
  # Add Nodes to Graph if not already there
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

  if e in self:
    return e.oid

  self.nodes[A.oid].adj.add(B.oid, e)
  self.edges[e.oid] = e

  result = e.oid

proc addEdge*(self: var Graph, A: string, B: string, label: string,
  props: tuple = (), ident: string = $genOid()): string =
  ## Add Edge to Graph.
  let e = newEdge(self.nodes[A], self.nodes[B], label, properties = props, ident = ident)

  if e in self:
    return e.oid

  self.nodes[A].adj.add(B, e)
  self.edges[e.oid] = e

  result = e.oid

proc update*[T](self: var T, t: tuple): string =
  ## Update Node or Edge properties
  for prop, val in t.fieldPairs:
    self.properties.add(prop, %val)

  result = self.oid

proc numberOfNodes*(self: Graph): int =
  ## Return number of Nodes in Graph
  result = self.nodes.len

proc numberOfEdges*(self: Graph): int =
  ## Return number of Edges in Graph
  result = self.edges.len

proc hasEdge*(self: var Graph, A: string, B: string): bool =
  ## Check if there is an Edge between Nodes A and B.
  result = A in self.nodes and B in self.nodes[A].adj

