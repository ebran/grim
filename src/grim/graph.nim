# Standard library imports
import tables
import strutils
import sequtils
import sugar
import sets
import oids
import strformat
import db_sqlite

from std/wordwrap import wrapWords

# grim modules
import box
import dsl

type
  Edge = ref object
    oid*: string
    label*: string
    startsAt*: Node
    endsAt*: Node
    properties*: Table[string, Box]

  Node* = ref object
    oid*: string
    label*: string
    properties*: Table[string, Box]
    adj: Table[string, seq[Edge]]

  Graph* = ref object
    name*: string
    nodeTable: Table[string, Node]
    edgeTable: Table[string, Edge]
    nodeIndex: Table[string, seq[string]]
    edgeIndex: Table[string, seq[string]]

proc numberOfNodes*(self: Graph): int =
  ## Return number of Nodes in Graph
  result = self.nodeTable.len

proc numberOfEdges*(self: Graph): int =
  ## Return number of Edges in Graph
  result = self.edgeTable.len

proc nodeLabels*(self: Graph): seq[string] =
  ## Return all node labels in the graph
  for label in self.nodeIndex.keys:
    result.add(label)

proc edgeLabels*(self: Graph): seq[string] =
  ## Return all edge labels in the graph
  for label in self.edgeIndex.keys:
    result.add(label)

iterator nodes*(self: Graph, labels: varargs[string]): Node =
  ## Iterator for nodes with `labels` in graph
  # Empty `labels` means use all labels
  let markers =
    if labels.len == 0:
      self.nodeLabels
    else:
      @labels

  # Iterate over markers
  for label in markers:
    if label notin self.nodeLabels:
      continue
    # Iterate over nodes with same label
    for n in self.nodeIndex[label]:
      yield self.nodeTable[n]

iterator edges*(self: Graph, labels: varargs[string]): Edge =
  ## Iterator for edges with `labels` in graph
  # Empty `labels` means use all labels
  let markers =
    if labels.len == 0:
      self.edgeLabels
    else:
      @labels

  # Iterate over markers
  for label in markers:
    if label notin self.edgeLabels:
      continue
    # Iterate over nodes with same label
    for e in self.edgeIndex[label]:
      yield self.edgeTable[e]

proc `$`*(self: Graph): string =
  ## Pretty-print Graph
  let
    m = self.name
    i = self.numberOfNodes
    j = self.numberOfEdges

  var
    nodeStats = initCountTable[string]()
    edgeStats = initCountTable[string]()

  for n in self.nodes:
    nodeStats.inc(n.label)
  for e in self.edges:
    edgeStats.inc(e.label)

  result = fmt("<Graph \"{m}\" with {i} node(s) {nodeStats} and {j} edge(s) {edgeStats}>")

proc `$`*(t: Table[string, Box]): string =
  ## Pretty-print String table with Boxes
  result.add("{")
  for key, val in t.pairs:
    result.add(key & ": " & val.describe & ", ")
  if t.len > 0:
    # Delete trailing comma
    result.delete(result.len-2, result.len)
  result.add("}")

proc `$`*(n: Node): string =
  ## Pretty-print Node
  result = fmt("<Node {n.label} \"{n.oid}\">")

proc `$`*(e: Edge): string =
  ## Pretty-print Edge
  result = fmt("<Edge {e.label} (\"{e.startsAt.oid}\" => \"{e.endsAt.oid}\") \"{e.oid}\">")

proc `%`*(t: tuple): Table[string, Box] =
  ## Convert tuple to Table[string, Box]
  for label, value in t.fieldPairs:
    result[label] = initBox(value)

proc contains*(self: Graph, key: string): bool =
  ## Check if Node or Edge oid is in Graph
  result = key in self.nodeTable or key in self.edgeTable

proc contains*(self: Graph, key: Node): bool =
  ## Check if Node object is in Graph
  result = key.oid in self.nodeTable

proc contains*(self: Graph, key: Edge): bool =
  ## Check if Edge object is in Graph
  result = key.oid in self.edgeTable

proc `==`*(self, other: Node): bool =
  ## Check if two Nodes are equal
  result = self.oid == other.oid

proc `==`*(self, other: Edge): bool =
  ## Check if two Edges are equal
  result = self.oid == other.oid

proc newGraph*(name: string = "graph"): Graph =
  ## Create a new graph
  new result

  result.name = name

proc newNode*(label: string, properties: Table[string, Box] = initTable[string,
    Box](), oid: string = $genOid()): Node =
  ## Create a new node
  new result

  result.label = label
  result.properties = properties
  result.oid = oid

proc newEdge*(A: Node, B: Node, label: string,
    properties: Table[string, Box] = initTable[string, Box](),
        oid: string = $genOid()): Edge =
  ## Create a new edge
  new result

  result.startsAt = A
  result.endsAt = B
  result.label = label
  result.properties = properties
  result.oid = oid

proc addNode*(self: Graph, label: string, props: Table[string,
    Box] = initTable[string, Box](), oid: string = $genOid()): string =
  ## Add node to graph.
  let n = newNode(label, properties = props, oid = oid)

  # Don't add if node already in graph
  if n in self:
    return n.oid

  self.nodeTable[n.oid] = n
  self.nodeIndex.mgetOrPut(label, newSeq[string]()).add(n.oid)
  result = n.oid

proc addNode*(self: Graph, n: Node): string =
  ## Add node to graph.
  # Don't add if node already in graph
  if n in self:
    return n.oid

  self.nodeTable[n.oid] = n
  self.nodeIndex.mgetOrPut(n.label, newSeq[string]()).add(n.oid)
  result = n.oid

proc addEdge*(self: Graph, e: Edge): string =
  ## Add edge to graph.
  # Don't add if edge already in graph
  if e in self:
    return e.oid

  self.nodeTable[e.startsAt.oid].adj.mgetOrPut(e.endsAt.oid, newSeq[Edge]()).add(e)
  self.nodeTable[e.endsAt.oid].adj.mgetOrPut(e.startsAt.oid, newSeq[Edge]()).add(e)
  self.edgeTable[e.oid] = e
  self.edgeIndex.mgetOrPut(e.label, newSeq[string]()).add(e.oid)

proc addEdge*(self: Graph, A: Node, B: Node, label: string,
    props: Table[string, Box] = initTable[string, Box](),
        oid: string = $genOid()): string =
  ## Add edge to graph
  # Add nodes to graph if not already there
  if A notin self:
    discard self.addNode(A)
  if B notin self:
    discard self.addNode(B)

  let e = newEdge(A, B, label, properties = props, oid = oid)

  # Don't add if edge already in graph
  if e in self:
    return e.oid

  # Add edge to edges and to adjancy lists
  self.nodeTable[A.oid].adj.mgetOrPut(B.oid, newSeq[Edge]()).add(e)
  self.nodeTable[B.oid].adj.mgetOrPut(A.oid, newSeq[Edge]()).add(e)
  self.edgeTable[e.oid] = e
  self.edgeIndex.mgetOrPut(e.label, newSeq[string]()).add(e.oid)

  result = e.oid

proc addEdge*(self: Graph, A: string, B: string, label: string,
  props: Table[string, Box] = initTable[string, Box](), oid: string = $genOid()): string =
  ## Add edge to graph.
  let e = newEdge(self.nodeTable[A], self.nodeTable[B], label,
      properties = props, oid = oid)

  # Don't add if edge already in graph
  if e in self:
    return e.oid

  # Add edge to edges and to adjancy lists
  self.nodeTable[A].adj.mgetOrPut(B, newSeq[Edge]()).add(e)
  self.nodeTable[B].adj.mgetOrPut(A, newSeq[Edge]()).add(e)
  self.edgeTable[e.oid] = e
  self.edgeIndex.mgetOrPut(e.label, newSeq[string]()).add(e.oid)

  result = e.oid

proc update*[T](self: var T, p: Table[string, Box]): string =
  ## Update node or edge properties
  for prop, val in p.pairs:
    self.properties[prop] = val

  result = self.oid

proc hasEdge*(self: Graph, A: string, B: string): bool =
  ## Check if there is an edge between nodes A and B.
  result = A in self.nodeTable and B in self.nodeTable[A].adj

proc getNode*(self: Graph, node: string): var Node =
  ## Return `node` in graph
  result = self.nodeTable[node]

proc getEdge*(self: Graph, edge: string): var Edge =
  ## Return `egde` in graph
  result = self.edgeTable[edge]

iterator neighbors*(n: Node): string =
  ## Return neighbors to node `n`.
  for oid in n.adj.keys:
    yield oid

iterator neighbors*(self: Graph, n: string): string =
  ## Return neighbors to node oid `n` in graph `g`.
  for n in self.nodeTable[n].neighbors:
    yield n

iterator getEdges*(self: Graph, A: string, B: string): Edge =
  ## Iterator for all edges between `A` and `B`.
  for e in self.nodeTable[A].adj[B]:
    yield e

proc describe*(e: Edge, lineWidth: int = 100, propertyWidth: int = 20): string =
  ## Return a nice pretty-printed summary of the edge
  # Edge header
  result.add(fmt("{e.label} (\"{e.startsAt.oid}\" => \"{e.endsAt.oid}\") \"{e.oid}\"") & "\n")
  result.add("=".repeat(lineWidth) & "\n")

  # Pretty-print properties
  for prop, val in e.properties.pairs:
    result.add(prop.alignLeft(propertyWidth, '.')[
        0..propertyWidth-1] & " ")

    let desc = wrapWords($val, 72, false).indent(propertyWidth+1)[
        propertyWidth+1..^1]
    result.add(desc & "\n")

  if e.properties.len == 0:
    result.add("No properties")

proc describe*(n: Node, lineWidth: int = 100, propertyWidth: int = 20): string =
  ## Return a nice pretty-printed summary of the node
  # Node header
  result.add(fmt("{n.label} \"{n.oid}\"") & "\n")
  result.add("=".repeat(lineWidth) & "\n")

  # Pretty-print properties
  for prop, val in n.properties.pairs:
    result.add(prop.alignLeft(propertyWidth, '.')[
        0..propertyWidth-1] & " ")

    let desc = wrapWords($val, 72, false).indent(propertyWidth+1)[
        propertyWidth+1..^1]
    result.add(desc & "\n")

  if n.properties.len == 0:
    result.add("No properties")

proc describe*(g: Graph, lineWidth = 100): string =
  ## Return a nice pretty-printed summary of the graph `g`
  let
    # Longest node and edge labels
    longestNodeLabel = g.nodeLabels.map(x => x.len).foldl(max(a, b))
    longestEdgeLabel = g.edgeLabels.map(x => x.len).foldl(max(a, b))
    # Largest number of digits in node and edges
    longestNodeNumber = ($g.nodeLabels.map(x => g.nodeIndex[x].len).foldl(max(a, b))).len
    longestEdgeNumber = ($g.edgeLabels.map(x => g.edgeIndex[x].len).foldl(max(a, b))).len
    # Longest label and numbers
    longestLabel = max(longestNodeLabel, longestEdgeLabel)
    longestNumber = max(longestNodeNumber, longestEdgeNumber)
    # Calculate indent level
    indentLevel = longestLabel + longestNumber + 4

  var
    line: string
    info: string
    propertyCounter: CountTable[string]

  # Print headers
  line = "Graph \"$1\"".format(g.name)
  result.add("\n" & line.center(lineWidth) & "\n\n")

  # Print node information
  result.add("NODES".center(lineWidth) & "\n\n")
  for label, oids in g.nodeIndex.pairs:
    # Count properties for node type
    propertyCounter = initCountTable[string]()
    for oid in oids:
      propertyCounter.merge(toSeq(g.getNode(oid).properties.keys).toCountTable)
    propertyCounter.sort()

    # Pretty-print node properties
    info = ""
    for key, value in propertyCounter.pairs:
      info.add("$1 ($2), ".format(key, value))
    if propertyCounter.len > 0:
      # delete trailing comma
      info.delete(info.len-2, info.len)
    info = indent(info.wrapWords(72, false), indentLevel)
    info = info & "\n"

    # Paste label before node properties
    info[0..indentLevel-1] = "$1 ($2):".format(label, g.nodeIndex[
        label].len).alignLeft(indentLevel)

    # Horizontal separator
    info.add("-".repeat(lineWidth) & "\n")

    result.add(info)

  # Print edge information
  result.add("EDGES".center(lineWidth) & "\n\n")
  for label, oids in g.edgeIndex.pairs:
    # Count properties for edge type
    propertyCounter = initCountTable[string]()
    for oid in oids:
      propertyCounter.merge(toSeq(g.getEdge(oid).properties.keys).toCountTable)
    propertyCounter.sort()

    # Pretty-print edge properties
    info = ""
    for key, value in propertyCounter.pairs:
      info.add("$1 ($2), ".format(key, value))
    if propertyCounter.len > 0:
      # delete trailing comma
      info.delete(info.len-2, info.len)
    info = indent(info.wrapWords(72, false), indentLevel)
    info = info & "\n"

    # Paste label before edge properties
    info[0..indentLevel-1] = "$1 ($2):".format(label, g.edgeIndex[
        label].len).alignLeft(indentLevel)

    # Horizontal separator
    info.add("-".repeat(lineWidth) & "\n")

    result.add(info)

when isMainModule:
  # types
  # relationship object based on foreign key in SQL table
  type
    Relationship = object
      table: string
      label: string
      A: tuple[label: string, key: string]
      B: tuple[label: string, key: string]
      with_properties: bool

  # with_properties is optional but transfers the SQL column to edge properties
  proc initRelationship(
    table: string,
    label: string,
    A: tuple[label: string, key: string],
    B: tuple[label: string, key: string],
    with_properties: bool = false): Relationship =
    result = Relationship(table: table, label: label, A: A, B: B,
        with_properties: with_properties)

  # constants
  const
    # Define SQL queries
    the_queries = {
      "table": "SELECT * FROM \"$1\"", # get all columns from table
      "header": "SELECT name FROM PRAGMA_TABLE_INFO('$1')" # get column names for table
    }.toTable

    # Define graph nodes from SQL tables
    the_nodes = [
      "Customer",
      "Supplier",
      "Product",
      "Employee",
      "Category",
      "Order"
    ]

    # Define relationships from foreign keys in SQL tables
    the_relationships = [
      initRelationship(
        table = "Order",
        A = (label: "Employee", key: "EmployeeId"),
        B = (label: "Order", key: "Id"),
        label = "SOLD",
        with_properties = true),
      initRelationship(
        table = "OrderDetail",
        A = (label: "Order", key: "OrderId"),
        B = (label: "Product", key: "ProductId"),
        label = "PRODUCT"),
      initRelationship(
        table = "Product",
        A = (label: "Product", key: "Id"),
        B = (label: "Category", key: "CategoryId"),
        label = "PART_OF"
      ),
      initRelationship(
        table = "Product",
        A = (label: "Supplier", key: "SupplierId"),
        B = (label: "Product", key: "Id"),
        label = "SUPPLIES"
      ),
      initRelationship(
        table = "Employee",
        A = (label: "Employee", key: "Id"),
        B = (label: "Employee", key: "ReportsTo"),
        label = "REPORTS_TO"
      )
    ]

  # Initialize the graph
  var g = newGraph("northwind")

  # Open a connection to the database
  let db = open("Northwind_small.sqlite", "", "", "")

  # Create nodes from tables
  for tbl in the_nodes:
    # Read the column names for the node table
    let headers = db.getAllRows(sql(the_queries["header"].format(tbl))).concat

    # Iterate over table rows
    for row in db.fastRows(sql(the_queries["table"].format(tbl))):
      # Read data and add rows as nodes
      let data = zip(headers, row.map(x => x.guessBox)).toTable
      discard g.addNode(tbl, data, oid = "$1.$2".format(tbl, data["Id"]))

  # Create relationships from foreign keys in tables
  for rel in the_relationships:
    # Read the column names for the edge table
    let headers = db.getAllRows(sql(the_queries["header"].format(
        rel.table))).concat

    # Iterate over table rows
    for row in db.fastRows(sql(the_queries["table"].format(rel.table))):
      let
        # Read data
        data = zip(headers, row.map(x => x.guessBox)).toTable
        # get the node labels for A and B
        A = "$1.$2".format(rel.A.label, data[rel.A.key])
        B = "$1.$2".format(rel.B.label, data[rel.B.key])

      # Skip the edge if either of the foreign keys is missing
      if data[rel.A.key].isEmpty or data[rel.B.key].isEmpty:
        continue

      # Add the edge
      discard g.addEdge(A, B, rel.label, oid = "$1-$2".format(A, B))
