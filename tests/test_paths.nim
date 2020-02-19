# stdlib imports
import unittest
import sequtils
import sets
import strutils

# grim imports
import grim
import grim/utils

var g = newGraph("Path tester")

# Persons
discard g.addNode("Person", %(name: "Alice"), oid = "alice")
discard g.addNode("Person", %(name: "Bob"), oid = "bob")
discard g.addNode("Person", %(name: "Charlie"), oid = "charlie")

discard g.addEdge("alice", "bob", "KNOWS", %(since: 2012),
    oid = "alice-bob")
discard g.addEdge("bob", "charlie", "KNOWS", %(since: 2013),
    oid = "bob-charlie")

# Adresses
discard g.addNode("Address", %(street: "Anywhere Road 1",
    zip: 11111), oid = "first house")
discard g.addNode("Address", %(street: "Somewhere Street 1", zip: 11112),
    oid = "second house")

# Residence chain
discard g.addEdge("alice", "first house", "FIRST", %(
    date: "2017-03-24"), oid = "to-first house")
discard g.addEdge("alice", "first house", "FIRST", %(
    date: "2017-03-24"), oid = "to-first house again")
discard g.addEdge("first house", "second house", "MOVED_TO", %(
    date: "2017-03-24"), oid = "first house-second house")

when isMainModule:
  var pc = g
    .paths("Person")
    .step("FIRST", "Address")

  echo "There are $1 paths in the collection.".format(pc.len)

  for path in pc:
    echo path
