import json
import tables
import oids

type
  Edge = object
    oid: string
    label: string
    properties: JsonNode
    goingFrom: Node
    goingTo: Node

  Node = object
    oid: string
    label: string
    properties: JsonNode
    edges: Table[string, Edge]

  Graph = ref object
    nodes: Table[string, Node]

proc `%`(t: tuple): JsonNode =
  ## Quick wrapper around the generic JObject constructor.
  var propertyList: seq[tuple[key: string, val: JsonNode]] = @[]
  for prop, val in t.fieldPairs:
    propertyList.add((prop, %val))
  result = %propertyList

proc contains*(self: Graph, key: string): bool =
  ## Check if node oid is in Graph
  result = key in self.nodes

proc contains*(self: Graph, key: Node): bool =
  ## Check if node is in Graph
  result = key.oid in self.nodes

proc initNode*(label: string, properties: tuple = (),
    ident: string = ""): Node =
  ## Initialize a new Node
  # Generate oid
  let oid =
    if ident.len == 0:
      $genOid()
    else:
      ident

  result = Node(label: label, properties: %properties, oid: oid)

proc newGraph*(): Graph =
  ## Create empty graph
  new result

proc addNode*(self: var Graph, label: string, props: tuple = (),
    ident: string = ""): string =
  ## Add node to Graph
  let n = initNode(label, properties = props, ident = ident)
  self.nodes[n.oid] = n
  result = n.oid

proc addNode*(self: var Graph, n: Node, props: tuple = ()): string =
  ## Add node to Graph.  TODO: Update props
  self.nodes[n.oid] = n
  result = n.oid

proc addEdge*[T, U](self: var Graph, first: T, second: U, label: string,
    props: tuple = (), ident: string = ""): string =
  ## Add edge to Graph #TODO: add properties
  # Add nodes to graph if not already there
  if first notin self:
    self.addNode(first)
  if second notin self:
    self.addNode(second)
  # Generate oid
  let oid =
    if ident.len == 0:
      $genOid()
    else:
      ident

  result = ""

proc numberOfNodes*(self: Graph): int =
  ## Return number of nodes in Graph
  result = self.nodes.len

proc numberOfEdges*(self: Graph): int =
  ## Return number of edges in Graph
  result = 0

when isMainModule:
  var g = newGraph()

  let p1 = initNode("Person", (name: "John Doe", age: 24))
  let p2 = initNode("Person", (name: "Jane Doe", age: 22))
