<p align="center">
<img src="static/logo.svg" alt="grim" width=100>
</p>

# grim brings the property graph to Nim!

grim provides a native [labeled property graph](https://en.wikipedia.org/wiki/Graph_database#Labeled-property_graph) structure for the Nim language. The data storage model is similar to that implemented in the [Neo4j](https://neo4j.com) database and consists of two labeled entities: **Nodes** and **Edges**. Data is stored with key/value-pairs on the entities.

<p align="center">
<img src="static/map.svg" alt="grim" width=500>
</p>

## Using grim

grim is included in the package list provided by the Nimble package manager and can be used off-the-shelf with a recent Nim distribution.

### Prerequisites

Install the Nim compiler, see the [nim-lang homepage](https://nim-lang.org) for instructions.

### Installing

Install grim on your local machine with nimble:

```bash
nimble install grim
```

To use it in a project, add grim as a requirement in the .nimble file:

```nim
requires "grim"
```

## API

grim is designed with a user-friendly API. Example uses can be found in the tests/ folder, and there is a partial [tutorial](./tutorials/Northwind.nim) on the Northwind data set to demonstrate how to translate a relational SQL model to a property graph with grim. 

Auto-generated documentation of the grim library is found [here](https://ebran.github.io/grim). It is continuously being improved. Below are some other simple use cases. 

### Basic

Create a new graph:

```nim
import grim

var g = newGraph("my graph")
echo g.name    # "my graph"
doAssert g.numberOfNodes == 0 and g.numberOfEdges == 0
```
Next, add data to the graph. Nodes:

```nim
let 
  c1 = g.addNode("Country", %(name: "Sweden", GDP_per_capita: 53208.0))
  c2 = g.addNode("Country", %(name: "Norway", GDP_per_capita: 74536.0))
  c3 = g.addNode("Country", %(name: "Germany", GDP_per_capita: 52559.0))

  o1 = g.addNode("Organization", %(name: "NATO", founded: 1949, active: true))
  o2 = g.addNode("Organization", %(name: "EU", founded: 1993, active: true))
  o3 = g.addNode("Organization", %(name: "Nordic Council", founded: 1952))
```
Note:
- The `%`operator on tuples pairs of key/value store properties in heterogeneous data tables.
- `addNode` and `addEdge` return the `oid` for the node/edge. The `oid` is a unique string identifier that can be set via the `oid` argument to `addNode` and `addEdge` (it is auto-generated if the `oid` argument is omitted).

Here's how one can get data out of the graph:

```nim
doAssert g.node(c1).label == "Country"
doAssert g.node(c1)["name"] == "Sweden"
```
Add edges:

```nim
let
  e1 = g.addEdge(c1, o2, "MEMBER_OF", %(since: 1995))
  e2 = g.addEdge(c1, o3, "MEMBER_OF", %(since: 1952))
  e3 = g.addEdge(c2, o3, "MEMBER_OF", %(since: 1952, membership: "full"))
```
Note how the node `oids` are used to create the new edges (labeled "MEMBER_OF") with key/value properties. Here's how to get iterators over nodes and edges:

```nim
# Iterator over all nodes
for node in g.nodes:
  echo node.label, ": ", node     # prints node properties

# Iterator over all nodes with a certain label
for node in g.nodes("Country"):
  echo node.label, ": ", node     # prints node properties

# Iterator over all edges
for edge in g.edges:
  echo edge.label, ": ", edge     # prints edge properties

# Iterator over all edges with a certain label
for edge in g.edges("MEMBER_OF"):
  echo edge.label, ": ", edge     # prints edge properties

# Iterator over all edges between two nodes
for edge in g.getEdges(c1, o3):
  echo edge.label, ": ", edge     # prints edge properties
  
# Iterator over neighbor nodes
for node in g.neighbors(c1):
  echo node.label, ": ", node     # prints node properties
```
Note that the graph is directional, so `addEdge(A, B, "LABEL")` adds an edge with label "LABEL" pointing from A to B. All iterators take a `direction` argument to specify if you want to include edges/neighbors that are outgoing (`A->B`), incoming (`A<-B`) or both (`A<->B`). The direction is specified with the enum values `Direction.Out`, `Direction.In`, and `Direction.OutIn`.

### Loading and saving graphs

Graph structures can be loaded and saved in YAML format. grim uses the NimYAML library for this. Two procs `loadYaml` and `saveYaml` are available. Check the tests/ folder for an example of a graph YAML structure.

```nim
import grim

var g = loadYaml("example.yaml")  # Load graph from YAML file
g.saveYaml("example2.yaml")         # Save a copy of the file
```

### DSL for building graphs

A small DSL is provided to build graphs. A toy example:

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
This will make the graph available in the remainder of the code as the mutable variable `g`. This example shows how to access graph properties.

```nim
let
  p1 = g.node("a nice guy")
  p2 = g.node("a smart girl")

doAssert p1.label == "Character" and p2.label == "Character"
doAssert p1["name"].getStr == "Santa Claus"
doAssert p1["age"].getInt == 108
doAssert p2["name"].getStr == "Jane Austen"
doAssert p2["wealth"].getFloat == 10304.3

for e in g.edgesBetween("a nice guy", "a smart girl"):
  doAssert e.label == "DELIVERS"
  doAssert e["category"].getStr == "writing material"
  doAssert e["value"].getInt == 204
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
