import grim
import sets
import os
import unittest

suite "Input and output":
  test "Test YAML reader":
    var g = loadYaml(getAppDir() / "example.yaml")

    let
      p1 = g.nodes["new gal"]
      p2 = g.nodes["new guy"]
      rels = g.getEdges("new guy", "new gal")

    check:
      g.name == "Happy People"
      "new gal" in g
      "new guy" in g

      p1.label == "Person"
      p1.properties["name"].getStr == "Jane Doe"
      p1.properties["age"].getInt == 22
      p1.properties["smoker"].getBool == true

      p2.label == "Person"
      p2.properties["name"].getStr == "John Doe"
      p2.properties["age"].getInt == 24
      p2.properties["weight"].getFloat == 37.2

      g.numberOfNodes == 2

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
      rels[1].label == "INHERITS"
      rels[1].properties["amount"].getFloat == 1937.2

      g.numberOfEdges == 2

  test "Test saving graph to YAML":
    var g = loadYaml(getAppDir() / "example.yaml")

    g.saveYaml(getAppDir() / "example2.yaml", overwrite = true)

    let
      first = readFile(getAppDir() / "example.yaml")
      second = readFile(getAppDir() / "example2.yaml")

    check first == second


