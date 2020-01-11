import grim
import unittest
import sequtils

suite "DSL":
  test "build graph":
    graph g "People and Pets":
      nodes:
        Person:
          "new gal":
            name: "Jane Doe"
            age: 22
          "new guy":
            name: "John Doe"
            age: 24

      edges:
        "new gal" -> "new guy":
          MARRIED_TO:
            since: 2012

    let
      p1 = g.nodes["new gal"]
      p2 = g.nodes["new guy"]

    check:
      p1 in g
      p2 in g

      p1.label == "Person"
      p1.properties["name"].getStr == "Jane Doe"
      p1.properties["age"].getInt == 22

      p2.label == "Person"
      p2.properties["name"].getStr == "John Doe"
      p2.properties["age"].getInt == 24

      g.numberOfNodes == 2

    let rels = g.getEdges("new guy", "new gal")

    for r in rels:
      check:
        r in g
        r.startsAt == p1
        r.endsAt == p2

    check:
      g.neighbors("new gal") == @["new guy"].toHashSet
      g.neighbors("new guy") == @["new gal"].toHashSet

      rels[0].label == "MARRIED_TO"
      rels[0].properties["since"].getInt == 2012

      g.numberOfEdges == 1
