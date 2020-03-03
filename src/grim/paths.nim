# stdlib imports
import strutils
import hashes
import sets
import sequtils

# grim imports
import grim/entities

type
  ## A path member stores an edge.
  Member = ref object
    previous: Member
    next: Member
    value: Edge

  ## A path is an anchor node followed by a sequence of members.
  Path = ref object
    numberOfMembers: int
    anchor*: Node
    head: Member
    tail: Member

  ## Collection of paths
  PathCollection* = object
    paths: seq[Path]

proc newPath*(anchor: Node): Path =
  ## Create a new path with `anchor`.
  result = new Path
  result.anchor = anchor

proc newMember(value: Edge): Member =
  ## Create a new path member holding `value`.
  result = new Member
  result.value = value

proc initPathCollection*(): PathCollection =
  ## Initialize a new path collection
  result = PathCollection()

proc len*(p: Path): int =
  ## Return the length of the path.
  result = p.numberOfMembers

iterator items*(p: Path): Edge =
  ## Iterate over path member values.
  var m = p.head

  while not m.isNil:
    yield m.value
    m = m.next

proc first*(p: Path): Edge =
  ## Return the first edge in the path (O(1) operation).
  result = p.head.value

proc last*(p: Path): Edge =
  ## Return the last edge in the path (O(1) operation).
  result = p.tail.value

proc get*(p: Path, n: int): Edge =
  ## Return the `n`:th member of the path (O(n) operation).
  if n < 0 or n >= p.len:
    raise newException(ValueError, "$1 is out of bounds[0,...,$2] for path of length $3.".format(
        n, p.len-1, p.len))

  var counter = 0
  for e in p:
    if counter == n:
      return e
    counter.inc

proc add(p: Path, value: Edge): Path =
  ## Add a `value` to the end of the path.
  if p.len > 0:
    doAssert(p.tail.value.endsAt == value.startsAt, "Can only add step to end of path.")

  var m = newMember(value)
  m.previous = p.tail

  if p.len == 0:
    p.head = m
  else:
    p.tail.next = m

  p.tail = m

  p.numberOfMembers.inc

  result = p

proc copy(p: Path): Path =
  ## Return a copy of the path.
  result = newPath(p.anchor)

  for edge in p:
    discard result.add(edge)

proc hash*(p: Path): Hash =
  ## Create hash for path based on edge oids
  var h: Hash = 0

  for edge in p:
    h = h !& edge.oid.hash

  result = !$ h

proc `==`*(self, other: Path): bool =
  ## Check if two paths are equal.
  # If all goes well, the paths are the same
  result = true

  # Must have same lengths and anchors.
  if self.len != other.len or self.anchor != other.anchor:
    return false

  # Traverse both paths simultaneously for performance
  var
    m1 = self.head
    m2 = other.head

  while not m1.isNil:
    if m1.value != m2.value:
      return false
    m1 = m1.next
    m2 = m2.next

proc `$`*(m: Member): string =
  ## Stringify a path member.
  result = "Member: " & $(m.value)

proc `$`*(p: Path): string =
  ## Stringify a path.
  if p.len == 0:
    return "Empty path"

  result = "$1-step Path: $2 ($3)".format(p.len, p.anchor.label, p.anchor.oid)

  for edge in p:
    result &= " ="
    result &= "$1=> $2".format(edge.label, edge.endsAt.label)

  result &= " ($1).".format(p.tail.value.endsAt.oid)

proc pop*(p: Path): Edge =
  ## Remove the last path value and return it
  if p.len == 0:
    raise newException(ValueError, "Can not pop from zero-length path.")

  # Return value of last member
  result = p.tail.value

  # p == 1 is a special case
  if p.len == 1:
    p.head = nil
    p.tail = nil
  else:
    p.tail = p.tail.previous
    p.tail.next = nil

  p.numberOfMembers.dec

proc add*(pc: var PathCollection, p: Path) =
  ## Add a path to the path collection
  pc.paths.add(p)

iterator items*(pc: PathCollection): Path =
  ## Iterator for paths in PathCollection
  for path in pc.paths:
    yield path

proc len*(pc: PathCollection): int =
  result = pc.paths.len

proc step*(pc: PathCollection, edgeLabel, nodeLabel: string): PathCollection =
  ## Add a step to a path collection.
  # Return a modified copy of the path collection
  result = PathCollection()

  # Iterate over paths in collection
  for path in pc:
    # Iterate over edges of the path's end node
    # (anchor node if the path is empty)
    let edgeIt =
      if path.len == 0:
        path.anchor.edges
      else:
        path.tail.value.endsAt.edges

    for edge in edgeIt:
      # Add edge to (a copy of the) path ONLY IF edge- and node labels match
      if edge.label == edgelabel and edge.endsAt.label == nodeLabel:
        result.add(path.copy.add(edge))

proc steps*(pc: PathCollection, edgeLabel, nodeLabel: string,
    nsteps: int = 1): PathCollection =
  ## Repeat a number of fixed steps
  # Return a modified copy of the path collection
  result = pc
  # Take n steps
  for _ in countup(1, nsteps):
    result = result.step(edgeLabel, nodeLabel)

proc follow*(pc: PathCollection, edgeLabel, nodeLabel: string): PathCollection =
  ## Repeat steps until there are no further matching paths
  var
    proxy = pc             # proxy path collection used for the flow
    visited: HashSet[Path] # track path visited by the proxy

  while proxy.len > 0:
    proxy = proxy.step(edgeLabel, nodeLabel)

    for path in proxy.paths:
      visited.incl(path.copy)

  # Return a modified copy of the path collection
  result = PathCollection()
  for path in visited:
    result.add(path)
