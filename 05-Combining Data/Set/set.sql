-- UNION--
-- combine the data from employees and customers into one table
SELECT FirstName, LastName FROM Sales.Customers
UNION
SELECT FirstName, LastName FROM Sales.Employees
-- for UNION, order of the columns does not matter

-- UNION ALL
-- faster than UNION, becuase it doesn't need to consider the duplicates.
-- if you are sure there is no duplicates, use UNION ALL
-- use UNION ALL to find duplicates and quality issues
SELECT FirstName, LastName FROM Sales.Customers
UNION ALL
SELECT FirstName, LastName FROM Sales.Employees


-- EXCEPT --
-- return all distinct rows from the first query that are not found in the second query.
-- its the only one where the order of the queries affect the final result.

-- Find the employees who are not customers at the same time.
SELECT FirstName, LastName FROM Sales.Employees
EXCEPT
SELECT FirstName, LastName FROM Sales.Customers
-- Find the customers who are not employees at the same time.
SELECT FirstName, LastName FROM Sales.Customers
EXCEPT
SELECT FirstName, LastName FROM Sales.Employees

--INTERSECT--
-- find the employees, who are also customers
SELECT FirstName, LastName FROM Sales.Employees
INTERSECT
SELECT FirstName, LastName FROM Sales.Customers

-- UNION use case
-- orders data are stored in separate tables (orders and ordersarchive)
-- combine all orders data into one report without duplicates.
SELECT 
    'Orders' AS SourceTable,
    [OrderID]
    ,[ProductID]
    ,[CustomerID]
    ,[SalesPersonID]
    ,[OrderDate]
    ,[ShipDate]
    ,[OrderStatus]
    ,[ShipAddress]
    ,[BillAddress]
    ,[Quantity]
    ,[Sales]
    ,[CreationTime]
FROM Sales.orders
UNION 
SELECT 
'OrdersArchive' AS SourceTable,
    [OrderID]
    ,[ProductID]
    ,[CustomerID]
    ,[SalesPersonID]
    ,[OrderDate]
    ,[ShipDate]
    ,[OrderStatus]
    ,[ShipAddress]
    ,[BillAddress]
    ,[Quantity]
    ,[Sales]
    ,[CreationTime]
FROM Sales.OrdersArchive
ORDER BY OrderID

-- EXCEPT use case
-- data completeness check: EXCEPT operator can be used to compare tables to detect discrepencies between databases.
-- data immigration, where you check if all the data was moved to the new table or destination table
-- check the table A EXCEPT table B, and then the opposite
-- that way if the query result is empty, you know that the two tables are identical.
