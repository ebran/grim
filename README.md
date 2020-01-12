![grim-icon-small](static/grim-icon-small.png)

# grim - brings graphs to Nim

grim is a graph data structure for the Nim language, written in the Nim language, and inspired by the Neo4j database. Data is stored in **Nodes** and **Edges**. Each Node and Edge has a label for grouping data, and can store an arbitrary of (Json-like) properties. 

## Getting up and running

grim is packaged with the nimble, the Nim package manager and should be easy to use with a recent Nim distribution.

### Prerequisites

You need the Nim compiler, obviously. See the [nim-lang homepage](https://nim-lang.org) for easy installation instructions.

### Installing

grim is easily used with the nimble package manager. To install on your local computer use

```
nimble install grim
```

To use it in your own project add as requirement to the .nimble file:

```
requires "grim"
```

## Usage

grim is hopefully quite easy to use. Some use cases can be found in the tests/ folder. Here are some other examples. The auto-generated documentation can be found here.

### Basic

A graph consists of nodes and edges. Both nodes and edges carry a label for categorization, and both nodes and edges can store data attributes in key/value pairs. First, create a new graph:

```nim
import grim

var g = newGraph("my graph")
echo g.name    # "my graph"
doAssert g.numberOfNodes == 0 and g.numberOfEdges == 0
```

The graph variable must be mutable. Second, add some data to the graph. First, nodes:

```nim
let 
  c1 = g.addNode("Country", %(name: "Sweden", GDP_per_capita: 53208.0))
  c2 = g.addNode("Country", %(name: "Norway", GDP_per_capita: 74536.0))
  c3 = g.addNode("Country", %(name: "Germany", GDP_per_capita: 52559.0))

  o1 = g.addNode("Organization", %(name: "NATO", founded: 1949, active: true))
  o2 = g.addNode("Organization", %(name: "EU", founded: 1993, active: true))
  o3 = g.addNode("Organization", %(name: "Nordic Council", founded: 1952))
```

- The `%`operator can be used on tuples of key/value pairs to store properties in heterogeneous tables.

- `addNode` and `addEdge` return the `oid` for the node/edge. The `oid` is a unique string that is either specified with the `oid=` argument when creating the node or else auto-generated. If the `oid` is not desired, it must be explicitly discarded.

Read data from the graph:

```nim
doAssert g.getNode(c1).label == "Country"
doAssert g.getNode(c1).properties["name"] == "Sweden"
```

  Now, add edges to the graph:

```nim
let
  e1 = g.addEdge(c1, o2, "MEMBER_OF", %(since: 1995))
  e2 = g.addEdge(c1, o3, "MEMBER_OF", %(since: 1952))
  e3 = g.addEdge(c2, o3, "MEMBER_OF", %(since: 1952, membership: "full"))
```

The `oids`of the nodes are used to create a new edge (with label "MEMBER_OF")  with properties. Some information of the graph:

```nim
# Iterator over all nodes
for node in g.nodes:
  echo node.label, ": ", node.properties

# Iterator over all edges
for edge in g.edges:
  echo edge.label, ": ", edge.properties

# Iterator over all edges between two nodes
for edge in g.getEdges(c1, o3):
  echo edge.label, ": ", edge.properties
  
# Iterator over neighbor nodes
for node in g.neighbors(c1):
  echo node.label, ": ", node.properties
```



### Loading and saving graphs

Graph structures can be loaded and saved in YAML format. grim uses the NimYAML library for this. The two procs `loadYaml` and `saveYaml` are available.

```nim
import grim

var g = loadYaml("example.yaml")  # Load graph from YAML file
g.saveYaml("example2.yaml")         # Save a copy of the file
```



### DSL for specifying graphs

A small DSL is provided to construct graphs. Consider this toy example:

```nim
import grim

graph g "Some people":
  nodes:
  	Person:
  		"a nice guy":
  		  name: "Santa Claus"
  		  age: 108
  		"a smart girl":
  		  name: "Jane Austen"
  		  wealth: 10304.3
  edges:
    "a nice guy" -> "a smart girl":
      DELIVERS:
        category: "writing material"
        value: 204
```
This will make the graph structure available to the rest of the code as a mutable variable `g`. This example shows how to access the graph properties.

```nim
let
  p1 = g.getNode("a nice guy")
  p2 = g.getNode("a smart girl")

doAssert p1.label == "Character" and p2.label == "Character"
doAssert p1.properties["name"].getStr == "Santa Claus"
doAssert p1.properties["age"].getInt == 108
doAssert p2.properties["name"].getStr == "Jane Austen"
doAssert p2.properties["wealth"].getFloat == 10304.3

for e in g.getEdges("a nice guy", "a smart girl"):
  doAssert e.label == "DELIVERS"
  doAssert e.properties["category"].getStr == "writing material"
  doAssert e.properties["value"].getInt == 204
```



## Running the tests

The tests can be run with nimble, they test basic usage of the package such as creating and modifying graphs, the DSL, and loading/saving graphs as YAML.

```
nimble test
```

## Built With

* [Nim](https://nim-lang.org/) - The Nim programming language
* [NimYAML](https://nimyaml.org/) - A pure YAML implementation for Nim.

## Contributing

I'll be happy to accept and review PRs and discuss other things on submitted to Issues.

## Authors

* **Erik G. Brandt** - *Original author* - [ebran](https://github.com/ebran)

## License

This project is licensed under the MIT License.
