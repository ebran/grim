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

Some constants are defined before proceeding:

```nim
const
  queries = {
    "table": "SELECT * FROM \"$1\"", 
    "header": "SELECT name FROM PRAGMA_TABLE_INFO('$1')"
  }.toTable

  nodes = ["Customer", "Supplier", "Product", "Employee", 				"Category", "Order"]
```
YOU ARE HERE

queries: SQL queries

table: Get all columns from table

header: # Get column names for table

nodes:   ## SQL table names are used as node labels and the rows in the tables are converted to nodes. 
  Non-foreign keys are not converted to edge properties by default

```nim
  ## Relationships defined from foreign keys in the SQL tables
  relationships = [
    # Employee - SOLD -> Order
    initRelationship(
      table = "Order",
      A = (label: "Employee", key: "EmployeeId"),
      B = (label: "Order", key: "Id"),
      label = "SOLD"),
    # Order - PRODUCT -> Product
    initRelationship(
      table = "OrderDetail",
      A = (label: "Order", key: "OrderId"),
      B = (label: "Product", key: "ProductId"),
      label = "PRODUCT",
      use_properties = true),        # convert the non-foreign keys to edge properties
    initRelationship(
      # Product - PART_OF -> Category
      table = "Product",
      A = (label: "Product", key: "Id"),
      B = (label: "Category", key: "CategoryId"),
      label = "PART_OF"
    ),
    initRelationship(
      # Supplier - SUPPLIES -> Product
      table = "Product",
      A = (label: "Supplier", key: "SupplierId"),
      B = (label: "Product", key: "Id"),
      label = "SUPPLIES"
    ),
    initRelationship(
      # Employee - REPORTS_TO -> Employee
      table = "Employee",
      A = (label: "Employee", key: "Id"),
      B = (label: "Employee", key: "ReportsTo"),
      label = "REPORTS_TO"
    )
  ]

stdout.write("Building graph from relational model... ")

# Initialize the graph
var g = newGraph("northwind")

# Open a connection to the database
let db = open("Northwind_small.sqlite", "", "", "")

# Create nodes from database tables
for tbl in nodes:
  # Read the column names for the node table
  let headers = db.getAllRows(sql(queries["header"].format(tbl))).concat

  # Iterate over table rows
  for row in db.fastRows(sql(queries["table"].format(tbl))):
    # Read data and add rows as nodes
    let data = zip(headers, row.map(x => x.guessBox)).toTable
    discard g.addNode(tbl, data, oid = "$1.$2".format(tbl, data["Id"]))

# Create relationships from foreign keys in tables
for rel in relationships:
  # Read the column names for the edge table
  let headers = db.getAllRows(sql(queries["header"].format(
      rel.table))).concat

  # Iterate over table rows
  for row in db.fastRows(sql(queries["table"].format(rel.table))):
    # Read data
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

echo "[OK]\n"
```
## PART 2: QUERYING THE GRAPH
```nim
echo "Question: How are the employees organized? Who reports to whom?"
echo "-".repeat(72)

# Loop over outgoing "REPORTS_TO" edges, pointing from employee to manager.
for edge in g.edges("REPORTS_TO"):
  let
    employee = edge.startsAt
    manager = edge.endsAt

  echo "$1 $2 ($3) is manager to $4 $5 ($6).".format(manager["FirstName"],
      manager["LastName"], manager["Id"], employee["FirstName"], employee[
          "LastName"], employee["Id"])

echo ""
echo "Question: How many orders were made by each part of the hierarchy?"
echo "-".repeat(72)

type
  ## Container for employee's sales statistics
  OrderStats = object
    id: BiggestInt           # Employee id
    reports: seq[BiggestInt] # Seq with employee id's reporting to this employee
    direct: BiggestInt       # The number of direct orders
    indirect: BiggestInt     # The number of indirect orders via reporting employees
    total: BiggestInt        # The sum of direct and indirect orders

# Create a table with order statistics that is easily sorted by employee
var orders: OrderedTable[BiggestInt, OrderStats]

# Initialize OrderStats objects for all employees
for node in g.nodes("Employee"):
  let employee = node["Id"].getInt
  orders[employee] = OrderStats(id: employee)

# Find how many other employees that are reporting to each employee
for edge in g.edges("REPORTS_TO"):
  let
    employee = edge.endsAt["Id"].getInt
    reporter = edge.startsAt["Id"].getInt
  orders[employee].reports.add(reporter)

# Count direct orders for each employee
for edge in g.edges("SOLD"):
  let employee = edge.startsAt["Id"].getInt
  orders[employee].direct.inc

# Sum the orders for each reporter to get the number of indirect orders.
# Then sum direct and indirect orders to get the total orders.
for order in orders.mvalues:
  order.indirect = order.reports.map(x => orders[x].direct).sum
  order.total = order.direct + order.indirect

# Pretty-print descending results sorted by total number of orders.
echo "\nEmployee       Reporters                     Total Orders"
echo ".".repeat(72)
for order in toSeq(orders.values)
  .sortedByIt(it.total)
  .reversed:
  echo fmt"{order.id:<15}{order.reports:<30}{order.total:<}"
```
## PART 3: UPDATING THE GRAPH
```nim
echo ""
echo "Task: Make Janet report to Steven"
echo "-".repeat(72)

# Proc to easily find manager and employeer
proc getEmployee(n: int): string =
  for node in g.nodes("Employee"):
    if node["Id"].getInt == n:
      return node.oid

let
  janet = getEmployee(3)  # Janet
  steven = getEmployee(5) # Steven

# Who was Janet reporting to originally?
for edge in g.edges("REPORTS_TO"):
  if edge.startsAt.oid == janet:
    echo "$1 $2 is reporting to $3 $4.".format(edge.startsAt["FirstName"],
        edge.startsAt["LastName"], edge.endsAt["FirstName"], edge.endsAt["LastName"])
    break

# Delete Janet's reporting relationships
for edge in g.node(janet).edges:
  if edge.label == "REPORTS_TO":
    discard g.delEdge(edge.oid)

# Add a new reporting relation for Janet
discard g.addEdge(janet, steven, "REPORTS_TO")

# Who is Janet reporting to now?
for edge in g.edges("REPORTS_TO"):
  if edge.startsAt.oid == janet:
    echo "$1 $2 is now reporting to $3 $4.".format(edge.startsAt["FirstName"],
        edge.startsAt["LastName"], edge.endsAt["FirstName"], edge.endsAt["LastName"])
    break
```