-- indexes are data structures that provides quick access to data, optimizing the speed of your queries
-- types
-- structure wise: clustered index and non-clustered index
-- storage: rowstrore index, columnstore index
-- functions: unique index, filtered index

-- Heap: table without clustered index
-- in a heap, rows are stored in the data pages according to the page size and then moves to another page to store the rest of the data


-- clustered index

-- heap stack: data are inserted here randomly
SELECT
*
INTO Sales.DBCustomers
FROM Sales.Customers

-- clustered index, if nothing is defined then it is nonclustered as default
CREATE CLUSTERED INDEX idx_DBCustomers_CustomerID
ON Sales.DBCustomers(CustomerID)

-- to drop index 
DROP INDEX idx_DBCustomers_CustomerID ON Sales.DBCustomers



-- columnstore index


-- Unique index
-- ensure no duplicate values exist in specific column
-- writing will be a bit slower, but reading will be much faster

SELECT * FROM Sales.Products

CREATE UNIQUE NONCLUSTERED INDEX idx_product_product
ON Sales.Products (Product)

INSERT INTO Sales.Products (ProductID, Product) VALUES (106, 'Caps') -- cannot put duplicates here

-- filtered index
-- an index that includes only rows meeting the specified conditions
SELECT * FROM Sales.Orders
-- DROP INDEX idx_orders_orderstatus ON Sales.Orders
CREATE NONCLUSTERED INDEX idx_orders_orderstatus
ON Sales.Orders (OrderID)
WHERE OrderStatus = 'Delivered'

SELECT * FROM Sales.Orders WHERE OrderStatus = 'Shipped' -- will be slower
SELECT * FROM Sales.Orders WHERE OrderStatus = 'Delivered' -- will be Faster


-- How and when to choose the right index
/*
HEAP: 
it is a table without any index. so it can be used for fast inserts, not suitable for fast writes. 
used for temp tables where we want to insert the data fast and get rid of it later

Clustered index (rowstore) (default):
basically used for primary keys, if not, then for date columns. 
used in OLTP (finance, banking, etc)


columnstore index: 
for analytical queries, reduces size of large table 
used in OLAP (data warehouse, business intelligence, Reporting, etc)

Non-clustered index:
for non-primarykey columns (foreign keys, joins, filters, etc)

filtered index:
targeting a subset of data to be accessible faster, reduces size of index

unique index:
enforces uniqueness, impproves query speed



*/







