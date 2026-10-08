-- ISNULL - it's going to check the null values inside a column and change the NULL values to anything else
-- the replacement value can be hardcoded
-- as well as another column value of that row. but if that also has NULL in that row, replacement would also be NULL
-- limited to two values and slower than coalesce
-- SQL server - ISNULL
-- ORACLE - NVL
-- MySQL - IFNULL

-- COALESCE() returns the first non-null value from a list
-- it's going to check all the values from the list if the previous one gives a null
-- unlimited options, but a bit slower than isnull
-- available in all databases, so migration from one database to another is easy.

-- use cases of coalesce and null: handle the NULL before doing data aggregations


-- find the average score of the customers
SELECT
CustomerID,
score,
AVG(Score) OVER() avgscores
FROM Sales.Customers 

SELECT 
customerID,
score,
AVG(score) OVER() avgscore1,
AVG(COALESCE(score, 0)) OVER() avgscore2
FROM Sales.Customers

-- display the full name of the customers in a single field
-- by merging their first and last names
-- and add 10 bonus points to each customers score
SELECT
CustomerID,
FirstName,
LastName,
FirstName + ' ' + COALESCE(LastName, '') AS full_name,
Score,
COALESCE(Score, 0) + 10 AS score_with_bonus
FROM Sales.Customers

-- handle nulls when joining tables
-- handle nulls before sorting data
-- sort the customers from lowest to highest scores, with nulls appearing last
-- method 1: replace the null with a very big number
SELECT 
CustomerID,
Score,
COALESCE(Score, 9999999)
FROM Sales.Customers
ORDER BY COALESCE(Score, 9999999)
-- method 2: 
SELECT 
CustomerID,
Score
FROM Sales.Customers
ORDER BY CASE WHEN Score IS NULL THEN 1 ELSE 0 END, Score

-- NULLIF
-- compares two expressions:
-- NULL, if they are equal
-- first value, if they are not equal
-- use case: division by zero, preventing the error of dividing by zero
-- find the sales price for each order by dividing the sales by quantity
SELECT
OrderID,
Sales,
Quantity,
Sales/NULLIF(Quantity, 0) AS price
FROM Sales.Orders

-- IS NULL returns true if the value if NULL
-- IS NOT NULL returns true if the value is not null, otherwise it's going to return false
-- use case: searching for missing information/nulls

-- identify the customers who have no scores
SELECT
*
FROM Sales.Customers
WHERE Score IS NULL
-- identify the customers who have scores
SELECT
*
FROM Sales.Customers
WHERE Score IS NOT NULL

-- IS NULL use case: anti joins. finding the unmatched rows between two tables
-- list all details for customers who have not placed any orders
SELECT
Sales.Customers.*, Sales.Orders.OrderID
FROM Sales.Customers
LEFT JOIN Sales.Orders
ON Sales.Customers.CustomerID = Sales.Orders.CustomerID
WHERE Sales.Orders.OrderID IS NULL