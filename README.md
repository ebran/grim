<p align="center">
<img src="static/logo.svg" alt="grim" width=100>
</p>

# grim brings property graphs to Nim!!

Grim brings the [labeled property graph](https://en.wikipedia.org/wiki/Graph_database#Labeled-property_graph) (LPG) data structure to the Nim language. This storage model is used in the [Neo4j](https://neo4j.com) database and consists of labeled **Nodes** and **Edges**. The data itself is stored in key/value-pairs on these entities.

<p align="center">
<img src="static/map.svg" alt="grim" width=500>
</p>

**News:** [2020-02-07] v0.2.0 released! See the [Changelog](Changelog.md).

------

[Using grim](#using-grim) | [Documentation and API](#documentation-and-api) | [Running the tests](#running-the-tests) | [Built with](#built-with) | [Contributing](#contributing) | [Authors](#authors) | [License](#license)

## Using grim

Grim is provided with the Nimble package manager in recent Nim distributions.

### Prerequisites

Install the Nim compiler; see the [nim-lang homepage](https://nim-lang.org) for instructions.

### Installing

Use `nimble` to install `grim` on your local machine:

```bash
nimble install grim
```

Use `grim` in a project by adding
```nim
requires "grim"
```
to its .nimble file.

## Documentation and API

[Basic](#basic) | [Iteration](#iteration) | [Loading/saving](loading-and-saving-graphs) | [Graph-building DSL](#dsl-for-building-graphs) | [Neo4j](#communicating-with-neo4j-database) | [Paths](#paths) | [Navigating paths](#navigating-paths)

The `grim` API is quite user-friendly. Use examples are found in the .nim files in the tests/ folder. The [Northwind tutorial](./tutorials/Northwind.nim) demonstrates how a relational SQL model (of the sales in a small company) is translated to the labeled property graph provided by `grim`. 

The `grim` documentation is continuously improved and is [hosted on Github](https://ebran.github.io/grim). 

### Basic

Create a new graph:

```nim
import grim

var g = newGraph("my graph")
echo g.name    
# => "my graph"
doAssert g.numberOfNodes == 0 and g.numberOfEdges == 0
```
Add nodes to the graph:
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
- The `%`operator converts tuples to key/value properties that are stored in heterogeneous data tables on the LPG.
- `addNode` and `addEdge` return `oid`s for the entities (node or edge). The `oid` is a unique (string) identifier for the entity that can be explicitly set with the `oid` argument to `addNode` and `addEdge`, or is auto-generated if the `oid` argument is omitted.

Here is how data is extracted from the graph:

```nim
doAssert g.node(c1).label == "Country"
doAssert g.node(c1)["name"] == "Sweden"
```
Note:
- The `oid`s are used to identify the node.

Add edges to the graph:
```nim
let
  e1 = g.addEdge(c1, o2, "MEMBER_OF", %(since: 1995))
  e2 = g.addEdge(c1, o3, "MEMBER_OF", %(since: 1952))
  e3 = g.addEdge(c2, o3, "MEMBER_OF", %(since: 1952, membership: "full"))
```
Note:
- The `oid`s are used to identify the nodes and create the new edges (labeled "MEMBER_OF") with key/value properties. 
- Since no `oid` argument is given to `addEdge`, the `oid` is autogenerated (and returned in the `e1`, `e2`, and `e3` variables).

### Iteraterating over nodes and edges

Iterate over all nodes:
```nim
for node in g.nodes:
  echo node.label, ": ", node     
```
Iterate over all nodes with a certain label:
```nim
for node in g.nodes("Country"):
  echo node.label, ": ", node
```
Iterate over all edges:
```nim
for edge in g.edges:
  echo edge.label, ": ", edge
```
Iterate over all edges with a certain label:
```nim
for edge in g.edges("MEMBER_OF"):
  echo edge.label, ": ", edge
```
Iterate over all edges between two nodes:
```nim
for edge in g.edgesBetween(c1, o3):
  echo edge.label, ": ", edge
```
Iterate over neighbor nodes:
```nim
for node in g.neighbors(c1):
  echo node.label, ": ", node
```
Note:
- The graph is directional so `addEdge(A, B, "LABEL")` adds an edge with label "LABEL" pointing from A to B. 
- All iterators take a `direction` argument that specifies whether to include outgoing (`A->B`), incoming (`A<-B`) or both (`A<->B`) edges/neighbors.
- The direction is specified with the enum values `Direction.Out`, `Direction.In`, and `Direction.OutIn`.

### Loading and saving graphs

Graph structures can be loaded and saved in YAML format with the help of the [NimYAML](https://nimyaml.org/) library. The two procs `loadYaml` and `saveYaml` can be used (there are examples in the `tests/` folder).

```nim
import grim

var g = loadYaml("example.yaml")    # Load graph from YAML file
g.saveYaml("example2.yaml")         # Save a copy of the file
```

### DSL for building graphs

A small DSL is provided to reduce boilerplate when building graphs. A toy example:
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
This will expose the graph in the remainder of the code as the mutable variable `g`. This example shows how to access graph properties:
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

The unit tests can be run with nimble, they test basic usage of the package such as creating and modifying graphs, the DSL, and loading/saving graphs as YAML.

```bash
nimble test
```

## Built With

* [Nim](https://nim-lang.org/) - The Nim programming language.
* [NimYAML](https://nimyaml.org/) - A pure YAML implementation for Nim.

## Contributing

I'll be happy to accept and review PRs and discuss other things on submitted to Issues.

## Authors

* **Erik G. Brandt** - *Original author* - [ebran](https://github.com/ebran)

## License

This project is licensed under the MIT License.
