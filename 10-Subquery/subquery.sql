-- a query inside another query
-- category: dependency wise: non-correlated subquery and correlated subquery
-- result type: scalar, row, table
-- location wise: select, from, join, where

-- find the products that have a price higher than the average price of all products
SELECT
*
FROM 
(
    -- subquery start
    SELECT
        ProductID,
        Price,
        AVG(Price) OVER() AS avgPrice
    FROM Sales.Products
    -- subquery end
) AS sub
WHERE Price > avgPrice

-- rank customers based on their total amount of sales
    SELECT
    *,
    RANK() OVER(ORDER BY total_sales DESC) AS customer_rank
    FROM
    (
        SELECT
    CustomerID,
    SUM(Sales) total_sales
    FROM Sales.Orders
    GROUP BY CustomerID
    ) AS t

-- show the productids, product names, prices and the total number of orders
SELECT
ProductID,
Product,
Price,
(SELECT COUNT(*) FROM Sales.Orders) AS totalOrders
FROM Sales.Products

-- show all customer details and find the total orders of each customer
-- main query
SELECT
c.*,
t.totalOrders
FROM Sales.Customers AS c
LEFT JOIN
(
-- subquery
SELECT
CustomerID,
COUNT(*) AS totalOrders
-- (SELECT OrderID, CustomerID FROM Sales.Orders)
FROM Sales.Orders
GROUP BY CustomerID
) as t
ON C.CustomerID = T.CustomerID