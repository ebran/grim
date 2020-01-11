# standard library imports
import tables
import sequtils
import strutils
import strformat
import oids

from streams import newFileStream, close
from os import fileExists
from sugar import `=>`

# grim modules
import graph
import box

# 3:rd party imports
import yaml

proc guessBox(s: string): Box =
  ## Return Box corresponding to (guessed) type contained in string
  case s.guessType:
    of yTypeInteger:
      initBox(s.parseBiggestInt)
    of yTypeFloat:
      initBox(s.parseFloat)
    of yTypeBoolFalse:
      initBox(false)
    of yTypeBoolTrue:
      initBox(true)
    of yTypeNull:
      initBox()
    else:
      initBox(s)

proc toYaml*[T](n: T): YamlNode =
  ## Cast object as new YamlNode
  newYamlNode(n)

proc toTable(node: YamlNode): Table[string, Box] =
  ## Convert YamlNode mapping to table
  # Only for mappings
  if node.kind != yMapping:
    raise newException(ValueError, fmt"Node must be a mapping, not {node.kind}!")

  for k, v in node.fields.pairs:
    # Can only map scalars, skip others
    if k.kind != yScalar or v.kind != yScalar:
      continue

    result[k.content] = guessBox(v.content)

proc loadYaml*(fileName: string): Graph =
  ## Read graph from YAML document
  # Load YAML as Document Object Model (DOM)
  var strm = newFileStream(fileName, fmRead)
  var dom = loadDom(strm)
  strm.close()

  # Setup graph
  result = newGraph(dom.root["graph"]["name"].content)

  # Load nodes
  for node in dom.root["graph"]["nodes"]:
    # Read properties if they exist
    let properties =
      if "properties" in toSeq(node.pairs).map(x => x[0].content):
        node["properties"].toTable
      else:
        initTable[string, Box]()

    discard result.addNode(
      node["label"].content,
      properties,
      oid = node["oid"].content
    )

  # Load edges
  for edge in dom.root["graph"]["edges"]:
    # Read oids if they exist
    let oid =
      if "oid" in toSeq(edge.pairs).map(x => x[0].content):
        edge["oid"].content
      else:
        $genOid()

    # Read properties if they exist
    let properties =
      if "properties" in toSeq(edge.pairs).map(x => x[0].content):
        edge["properties"].toTable
      else:
        initTable[string, Box]()

    discard result.addEdge(
      edge["startsAt"].content,
      edge["endsAt"].content,
      edge["label"].content,
      properties,
      ident = oid
    )

proc saveYaml*(g: Graph, fileName: string, force_overwrite: bool = false) =
  ## Save graph as YAML file
  # Exception if file exists and overwrite not forced
  if fileExists(fileName) and force_overwrite == false:
    raise newException(IOError, fmt"Error: {fileName} exists, use force_overwrite flag to bypass.")

  var
    domName: string = g.name
    domNodes: seq[YamlNode] = @[]
    domEdges: seq[YamlNode] = @[]

  # Build nodes as YamlNodes for DOM
  for node in g.nodes.values:
    var n = @[
      ("label".toYaml, node.label.toYaml),
      ("oid".toYaml, node.oid.toYaml)
    ]

    if node.properties.len > 0:
      let v = toSeq(node.properties.pairs).map(x => (x[0].toYaml, ($x[1]).toYaml))
      n.add(("properties".toYaml, v.toYaml))

    domNodes.add(n.toYaml)

  # Build edges as YamlNodes for DOM
  for edge in g.edges.values:
    var e = @[
      ("label".toYaml, edge.label.toYaml),
      ("oid".toYaml, edge.oid.toYaml),
      ("startsAt".toYaml, edge.startsAt.oid.toYaml),
      ("endsAt".toYaml, edge.endsAt.oid.toYaml)
    ]

    if edge.properties.len > 0:
      let v = toSeq(edge.properties.pairs).map(x => (x[0].toYaml, ($x[1]).toYaml))
      e.add(("properties".toYaml, v.toYaml))

    domEdges.add(e.toYaml)

  # Build YAML DOM
  var dom = initYamlDoc([
    ("graph".toYaml, [
      ("name".toYaml, domName.toYaml),
      ("nodes".toYaml, domNodes.toYaml),
      ("edges".toYaml, domEdges.toYaml)
    ].toYaml
    )
  ].toYaml)

  # Dump to file
  var strm = newFileStream(fileName, fmWrite)
  dom.dumpDom(strm)
  strm.close()
