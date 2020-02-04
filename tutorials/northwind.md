# Northwind tutorial

This tutorial is adapted from https://neo4j.com/developer/guide-importing-data-and-etl and shows how a relational (SQL) database is translated to a labeled property graph (LPG) with `grim`. The tutorial shows examples of how to query and update the LPG.

The general principles when translating a relation model to a graph model are:

1. A SQL table row is a node.

2. A SQL table name is a node label.

3. A join or foreign key in a SQL table defines edges (relationships).

This recipe yields a first iteration of an LPG that can be fine-tuned if necessary.

## PART 1: BUILDING THE LABELED PROPERTY GRAPH

The [Northwind data set](https://code.google.com/archive/p/northwindextended/downloads) contains the sales data for a fictitious company called Northwind Traders, which imports and exports specialty foods from around the world. The data tables in the Northwind set are related to each other as shown in the figure below.

![northwind](static/northwind.png)



The first task is to build a LPG from the Northwind data. The [full code](northwind.nim) from this tutorial is included in the repo and can be built and run with Nimble:

```bash
nimble northwind
```

### Imports

First, some of the pure standard libraries in Nim are imported and kept handy for the rest of the analysis. 

```nim
import sequtils, strformat, strutils
import sugar, math, algorithm, tables
```
Next Nim's impure `db_sqlite` module is used to read the Northwind database.
```nim
import db_sqlite
```
Impure means that the module depends on some external library, `libsqlite` in this case. This library must be installed on the computer for the program to run.

Finally, the `grim` library is imported to handle the LPG.

```nim
import grim
```
### Types

A `Relationship` object is needed to define how edges are created from foreign keys in the SQL table.

```nim
type
  Relationship = object
    table, label: string
    A, B: tuple[label: string, key: string] 
    useProperties: bool
```
The `Relationship` fields are:

- **table**: The name of the SQL table which contains the foreign key.

- **label**: The label of the created edge.

- **A** and **B**: A tuple with fields for the node label (*label*) and the foreign key (*key*) of the start (**A**) and end (**B**) nodes.

- **useProperties**: A boolean flag to determine whether the non-foreign keys in the table are to be converted to edge properties.

### Constants

We can define some constants at compile time:

```nim
const
  nodes = ["Customer", "Supplier", "Product", "Employee", 				"Category", "Order"]
  
  queries = {
    "table": "SELECT * FROM \"$1\"", 
    "header": "SELECT name FROM PRAGMA_TABLE_INFO('$1')"
  }.toTable
```
These are:

* **nodes**: The names of the SQL tables to be used as node labels (the rows in the tables become nodes). 

- **queries**: We define SQL queries to read from the database. The *table* query returns all columns of a table, and the *header* query returns all the column headers of a table. The `$1` is used with Nim's `format` function to substitute the actual table name.

We can now define relationships with the help of foreign keys in SQL tables. For instance, to relate employees to sold orders (Employee - SOLD -> Order) we can use a Relationship object

```nim
Relationship(
	table: "Order", 
    A: (label: "Employee", key: "EmployeeId"),
    B: (label: "Order", key: "Id"),
    label: "SOLD")
```
This says that this is a SOLD Relationship that goes from (A) the Employee node with key from the EmployeeId field of the Order table to (B) the Order node with key from the Id field of the Order table. In a similar manner, the Order - PRODUCT -> Product Relationship can be expressed with

```nim
Relationship(
	table: "OrderDetail",
    A: (label: "Order", key: "OrderId"),
    B: (label: "Product", key: "ProductId"),
    label: "PRODUCT",
    useProperties: true)
```
  In this case, we set `useProperties` to true to transfer all the keys from the OrderDetail table as edge properties.

### The labeled property graph (LPG)

We are now in a position to create a LPG representation of the Northwind data set with Grim.  Initialize a new LPG


```nim
var g = newGraph("northwind")
```
and open a connection to the database with Nim's standard library
```nim
let db = open("Northwind_small.sqlite", "", "", "")
```
Then, create nodes by iterating over the database tables
```nim
for tbl in nodes:
  # This gets the column name for the node table
  let headers = db.getAllRows(sql(queries["header"].format(tbl))).concat

  for row in db.fastRows(sql(queries["table"].format(tbl))):
    let data = zip(headers, row.map(x => x.guessBox)).toTable
    discard g.addNode(tbl, data, oid = "$1.$2".format(tbl, data["Id"]))
```
We explicitly set the node oids with the format "$1.$2", where $1 is substituted with the node label, and $2 is substituted with the unique key identifier (Id field) of the table.

With our relationship objects, creating the graph edges is fairly straightforward:

```nim
for rel in relationships:
  # This gets the column name for the edge table
  let headers = db.getAllRows(sql(queries["header"].format(
      rel.table))).concat

  for row in db.fastRows(sql(queries["table"].format(rel.table))):
    var data = zip(headers, row.map(x => x.guessBox)).toTable

    let
      # get the node labels for A and B
      A = "$1.$2".format(rel.A.label, data[rel.A.key])
      B = "$1.$2".format(rel.B.label, data[rel.B.key])
    
    # Skip the edge if either foreign key is missing
    if data[rel.A.key].isEmpty or data[rel.B.key].isEmpty:
      continue
    
    if rel.use_properties:
      # Transfer `data` to edge properties
      # delete the foreign keys from the properties
      data.del(rel.A.key)
      data.del(rel.B.key)
      # Add the edge
      discard g.addEdge(A, B, rel.label, properties = data,
          oid = "$1-$2".format(A, B))
    else:
      discard g.addEdge(A, B, rel.label, oid = "$1-$2".format(A, B))
```

## PART 2: QUERYING THE GRAPH

We have now transferred the relational (SQL) database to a labeled property graph (LPG)! We can now start querying the graph to obtain information of interest to us. For example:

###### How are the employees organized? Who reports to whom?

One way to achieve this with the grim library is to loop over REPORTS_TO edges, which point from the employee to the corresponding manager.

```nim
for edge in g.edges("REPORTS_TO"):
  let
    employee = edge.startsAt
    manager = edge.endsAt

  echo "$1 $2 ($3) is manager to $4 $5 ($6).".format(manager["FirstName"],
      manager["LastName"], manager["Id"], employee["FirstName"], employee[
          "LastName"], employee["Id"])
```
We can also ask:

###### How many orders were made by each part of the company's hierarchy?

To facilitate this analysis, it is convenient to define a new OrderStats object to represent the employees' sales statistics:

```nim
type
  OrderStats = object
    id: BiggestInt           
    reports: seq[BiggestInt]
    direct: BiggestInt
    indirect: BiggestInt
    total: BiggestInt
```
The fields are:

- **id**: Employee id

- **reports**: A sequence of the employee ids that are reporting to the current one.

- **direct**: Count of direct orders for the employee.

- **indirect**: Count of  indirect orders (via reporting employees) for the employee.

- **total**: Sum of direct and indirect orders for the employee.

Let's start with creating and initializing a HashTable of OrderStats, keyed by employee id:
```nim
var orders: OrderedTable[BiggestInt, OrderStats]
for node in g.nodes("Employee"):
  let employee = node["Id"].getInt
  orders[employee] = OrderStats(id: employee)
```
Find how many other employees that are reporting to each employee

```nim
for edge in g.edges("REPORTS_TO"):
  let
    employee = edge.endsAt["Id"].getInt
    reporter = edge.startsAt["Id"].getInt
  orders[employee].reports.add(reporter)

# Count direct orders for each employee
for edge in g.edges("SOLD"):
  let employee = edge.startsAt["Id"].getInt
  orders[employee].direct.inc
```
What about indirect?

Sum the orders for each reporter to get the number of indirect orders.

Then sum direct and indirect orders to get the total orders.

```nim
for order in orders.mvalues:
  order.indirect = order.reports.map(x => orders[x].direct).sum
  order.total = order.direct + order.indirect
```
Pretty-print descending results sorted by total number of orders.

echo "\nEmployee       Reporters                     Total Orders"
echo ".".repeat(72)
```nim
for order in toSeq(orders.values)
  .sortedByIt(it.total)
  .reversed:
  echo fmt"{order.id:<15}{order.reports:<30}{order.total:<}"
```
## PART 3: UPDATING THE GRAPH

Eventually, we will need to update the data in the LPG. This is easily done, the LPG is meant to be a dynamic data structure. Let's say that we want to:

###### Make Janet report to Steven!

```nim
# Proc to easily find manager and employeer
proc getEmployee(n: int): string =
  for node in g.nodes("Employee"):
    if node["Id"].getInt == n:
      return node.oid

let
  janet = getEmployee(3)  # Janet
  steven = getEmployee(5) # Steven
```
Who was Janet reporting to originally?

```nim
for edge in g.edges("REPORTS_TO"):
  if edge.startsAt.oid == janet:
    echo "$1 $2 is reporting to $3 $4.".format(edge.startsAt["FirstName"],
        edge.startsAt["LastName"], edge.endsAt["FirstName"], edge.endsAt["LastName"])
    break
```
Delete Janet's reporting relationships

```nim
for edge in g.node(janet).edges:
  if edge.label == "REPORTS_TO":
    discard g.delEdge(edge.oid)
```

Add a new reporting relation for Janet

```nim
discard g.addEdge(janet, steven, "REPORTS_TO")
```
Who is Janet reporting to now?

```nim
for edge in g.edges("REPORTS_TO"):
  if edge.startsAt.oid == janet:
    echo "$1 $2 is now reporting to $3 $4.".format(edge.startsAt["FirstName"],
        edge.startsAt["LastName"], edge.endsAt["FirstName"], edge.endsAt["LastName"])
    break
```