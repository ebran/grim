# stdlib imports
import tables

# grim imports
import grim/[entities, box]

proc find*[T: Node | Edge](self: Graph, label: string,
    data: Table[string, Box]): seq[Node] =
  ## Find patterns in the graph
  doAssert(false, "Not implemented")

proc shortestPath*(self: Graph, A: string, B: string): seq[Node] =
  ## Find shortest path between nodes `A` and `B`.
  assert(false, "Not implemented")
