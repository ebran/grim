# stdlib imports
import unittest
import zero_functional
import algorithm

# grim imports
import grim

suite "path collections":
  setup:
    var g = newGraph("Path tester")

    # Persons
    discard g.addNode("Person", %(name: "Alice"), oid = "alice")
    discard g.addNode("Person", %(name: "Bob"), oid = "bob")
    discard g.addNode("Person", %(name: "Charlie"), oid = "charlie")

    discard g.addEdge("alice", "bob", "KNOWS", %(since: 2012),
        oid = "alice-bob")
    discard g.addEdge("bob", "charlie", "KNOWS", %(since: 2013),
        oid = "bob-charlie")
    discard g.addEdge("bob", "charlie", "KNOWS", %(since: 2013,
        relatives: true),
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
    discard g.addEdge("bob", "second house", "MOVED_IN", %(
          date: "2020-02-16"), oid = "bob-second house")

  test "empty":
    var pc = g.navigate("Person")

    for path in pc:
      check path.len == 0

    check:
      pc.len == 3
      pc --> map(it.anchor["name"].getStr).sorted == @["Alice", "Bob", "Charlie"]

  test "fixed number of steps matching no paths":
    var pc = g
      .navigate("Person")
      .steps("KNOWS", "Person", 4)

    check pc.len == 0

  test "one step matching two paths":
    var pc = g
    .navigate("Person")
    .step("FIRST", "Address")

    check:
      pc.len == 2
      pc --> map(it.first.oid).sorted == @["to-first house", "to-first house duplicate"]

  test "two steps matching two paths":
    var pc = g
      .navigate("Person")
      .step("FIRST", "Address")
      .step("MOVED_TO", "Address")

    check:
      pc.len == 2
      pc --> map(it.len) == @[2, 2]

  test "two steps matching one path":
    var pc = g
      .navigate("Person")
      .step("KNOWS", "Person")
      .step("MOVED_IN", "Address")

    check pc.len == 1

    let p = pc --> take(1) --> reduce(it.elem)

    check:
      p.anchor.oid == "alice"
      p.first.oid == "alice-bob"
      p.nth(1).oid == "bob-second house"

    expect ValueError:
      discard p.nth(2)

  test "fixed number of steps matching two paths":
    var pc = g
      .navigate("Person")
      .steps("KNOWS", "Person", 2)

    check:
      pc.len == 2
      pc --> map(it.len) == @[2, 2]
      pc --> map(it.last.oid).sorted == @["bob-charlie", "bob-charlie-duplicate"]
      pc --> map(it.anchor.oid) == @["alice", "alice"]

    test "following pattern with five matches":
      var pc = g
        .navigate("Person")
        .follow("KNOWS", "Person")

      check:
        pc --> map(it.len).sorted == @[1, 1, 1, 2, 2]

        pc -->
          filter(it.len == 1) -->
          map(it.anchor["name"].getStr).sorted == @["Alice", "Bob", "Bob"]

        pc -->
          filter(it.len == 2) -->
          map(it.first.oid).sorted == @["alice-bob", "alice-bob"]

        pc -->
          filter(it.len == 2) -->
          map(it.last.oid).sorted == @["bob-charlie", "bob-charlie-duplicate"]
