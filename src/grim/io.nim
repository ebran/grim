import tables
import grim/graph
import grim/box
import yaml
import streams
import strutils
import strformat

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

proc toTable(node: YamlNode): Table[string, Box] =
  ## Convert YamlNode mapping to table
  if node.kind != yMapping:
    raise newException(ValueError, fmt"Node must be a mapping, not {node.kind}!")

  for k, v in node.fields.pairs:
    if k.kind != yScalar or v.kind != yScalar:
      continue

    result[k.content] = guessBox(v.content)

proc loadYaml*(fileName: string): Graph =
  ## Read graph from YAML document
  # Load YAML as Document Object Model (DOM)
  let dom = loadDom(newFileStream(fileName, fmRead))

  # Setup graph
  result = newGraph(dom.root["graph"]["name"].content)

  # Load nodes
  for node in dom.root["graph"]["nodes"]:
    discard result.addNode(
      node["label"].content,
      node["properties"].toTable,
      ident = node["oid"].content
    )

  # Load edges
  for edge in dom.root["graph"]["edges"]:
    discard result.addEdge(
      edge["startsAt"].content,
      edge["endsAt"].content,
      edge["label"].content,
      edge["properties"].toTable
    )
