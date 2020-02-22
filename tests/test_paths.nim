# stdlib imports
import unittest
import strutils

# grim imports
import grim

when isMainModule:
  var g = newGraph("Path tester")

  # Persons
  discard g.addNode("Person", %(name: "Alice"), oid = "alice")
  discard g.addNode("Person", %(name: "Bob"), oid = "bob")
  discard g.addNode("Person", %(name: "Charlie"), oid = "charlie")

  discard g.addEdge("alice", "bob", "KNOWS", %(since: 2012),
      oid = "alice-bob")
  discard g.addEdge("bob", "charlie", "KNOWS", %(since: 2013),
      oid = "bob-charlie")
  discard g.addEdge("bob", "charlie", "KNOWS", %(since: 2013, relatives: true),
    oid = "bob-charlie-duplicate")

  # Adresses
  discard g.addNode("Address", %(street: "Anywhere Road 1",
      zip: 11111), oid = "first house")
  discard g.addNode("Address", %(street: "Somewhere Street 1", zip: 11112),
      oid = "second house")

  # Chain of residences
  discard g.addEdge("alice", "first house", "FIRST", %(
      date: "2017-03-24", withMovers: false), oid = "to-first house")
  discard g.addEdge("alice", "first house", "FIRST", %(
      date: "2017-03-24", withMovers: true), oid = "to-first house duplicate")
  discard g.addEdge("first house", "second house", "MOVED_TO", %(
      date: "2019-06-12"), oid = "first house-second house")

  # Find persons, their first residence, and where they moved
  var pc = g
    .paths("Person")
    .step("FIRST", "Address")
    .step("MOVED_TO", "Address")

  echo "There are $1 paths in the collection.".format(pc.len)
  for path in pc:
    echo path, ", ", path.head.this.oid
  echo ""

    # Find chains of friends
  pc = g
    .paths("Person")
    .steps("KNOWS", "Person", 2)

  echo "There are $1 paths in the collection.".format(pc.len)
  for path in pc:
    echo path, ", ", path.tail.this.oid
  echo ""

  pc = g
    .paths("Person")
    .follow("KNOWS", "Person")

  echo "There are $1 paths in the collection.".format(pc.len)
  for path in pc:
    echo path, ", ", path.tail.this.oid
  echo ""
