import sequtils
import strutils
import sugar
import grim
import db_sqlite

# Read database
let db = open("Northwind_small.sqlite", "", "", "")

# Initialize graph
var g = initGraph("northwind")

# Define SQL queries
const
  tableQuery = "SELECT * FROM $1"
  headerQuery = "SELECT name FROM PRAGMA_TABLE_INFO('$1')"

for tbl in ["Customer", "Supplier", "Product", "Employee", "Category"]:
  # Read column names for table
  var headers = db.getAllRows(sql(headerQuery.format(tbl))).map(x => x[0])

  # Iterate over table and add nodes
  for row in db.fastRows(sql(tableQuery.format(tbl))):
    discard g.addNode(tbl, zip(headers, row.map(x => x.initBox)).toTable)

echo g
