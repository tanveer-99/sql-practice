-- window function does row level calculation
-- group by and window function differences
-- group by can be used for simple data analysis
-- while window function can be used for advanced data analysis
-- there are certain situations where group by is not enough and we have to use the window function

-- find the total sales across all orders
SELECT
SUM(Sales) AS total_sales
FROM Sales.Orders
-- find total sales for each product
SELECT
ProductID,
SUM(Sales) AS total_sales
FROM Sales.Orders
GROUP BY ProductID
-- find total sales for each product
-- additionally provide details such order id and order date
SELECT
    OrderID,
    OrderDate,
    ProductID,
    SUM(Sales) AS total_sales
FROM Sales.Orders
GROUP BY 
    OrderID,
    OrderDate,
    ProductID
-- the group by has limitations here as the grouping is done by the orderid now, duplicate product id total sales are shown
-- for this task, better to use the window function
SELECT 
    ProductID,
    OrderID,
    OrderDate,
    SUM(Sales) OVER(PARTITION BY ProductID) AS total_sales_by_product
FROM Sales.Orders
-- window functions returns a result for each row

-- find the total sales across all orders,
-- additionally, provide details such order id and order date
SELECT
OrderID,
OrderDate,
SUM(Sales) OVER() AS total_sales
FROM Sales.Orders
-- find the total sales for each product,
-- additionally, provide details such order id and order date
SELECT
OrderID,
OrderDate,
ProductID,
SUM(Sales) OVER(PARTITION BY ProductID) AS total_sales
FROM Sales.Orders
-- find the total sales across all orders,
-- find the total sales for each product,
-- additionally, provide details such order id and order date
SELECT
    OrderID,
    OrderDate,
    ProductID,
    Sales,
    SUM(Sales) OVER() AS total_sales,
    SUM(Sales) OVER(PARTITION BY ProductID) AS total_sales_by_product
FROM Sales.Orders
-- find the total sales across all orders,
-- find the total sales for each product,
-- find the total sales for each combination of product and order status
-- additionally, provide details such order id and order date
SELECT
    OrderID,
    OrderDate,
    ProductID,
    OrderStatus,
    Sales,
    SUM(Sales) OVER() AS total_sales,
    SUM(Sales) OVER(PARTITION BY ProductID) AS total_sales_by_product,
    SUM(Sales) OVER(PARTITION BY ProductID, OrderStatus) AS salesbyproductandorderstatus
FROM Sales.Orders
-- rank each order based on their sales from highest to lowest
-- additionally, provide details such order id and order date
SELECT
    OrderID,
    OrderDate,
    Sales,
    RANK() OVER(ORDER BY Sales DESC) RankSales
FROM Sales.Orders
-- rank the customers based on their total sales
SELECT
    CustomerID,
    SUM(Sales) AS total_sales,
    RANK() OVER(ORDER BY SUM(Sales) DESC) AS rankCustomers
FROM Sales.Orders
GROUP BY CustomerID