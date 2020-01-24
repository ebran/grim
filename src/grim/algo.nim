# stdlib imports
import tables

# grim imports
import graph
import box

proc find*[T: GrimNode | GrimEdge](self: Graph, label: string,
    properties: Table[string, Box]): seq[T] =
  ## Find patterns in the graph
  doAssert(false, "Proc not implemented")

proc shortestPath*(self: Graph, A: string, B: string): seq[GrimNode] =
  ## Find shortest path between nodes `A` and `B`.
  assert(false, "Proc not implemented")
