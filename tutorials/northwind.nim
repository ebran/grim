import sequtils
import sugar
import grim
import db_sqlite

var
  db: DbConn
  headers: seq[string]
  g: Graph

# Initialize graph
g = initGraph("northwind")

# Read database
db = open("Northwind_small.sqlite", "", "", "")

# Read column names for customers
headers = db.getAllRows(sql"SELECT name FROM PRAGMA_TABLE_INFO('Customer')").map(
    x => x[0])

# Iterate over customers and add as nodes
for row in db.fastRows(sql"SELECT * FROM Customer"):
  discard g.addNode("Customer", zip(headers, row.map(x => initBox(x))).toTable)

echo g
