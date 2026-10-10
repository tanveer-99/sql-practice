-- data quality issue
-- data quality issues: duplicates lead to inaccuracies in analysis 
-- COUNT() can be used to identify duplicates

-- identify duplicate rows to improve data quality with COUNT()
-- check whether the table 'orders' contain any duplicate rows
SELECT
    OrderID,
    COUNT(*) OVER(PARTITION BY OrderID) AS checkprimarykey
FROM Sales.Orders

SELECT
*
FROM 
(SELECT
    OrderID,
    COUNT(*) OVER(PARTITION BY OrderID) AS checkprimarykey
FROM Sales.OrdersArchive) AS t
WHERE checkprimarykey > 1 
-- COUNT use cases:
-- 1. overall analysis
-- 2. category analysis
-- 3. quality check: identify nulls
-- 4. quality check: identify duplicates


-- SUM() returns the sum of values in a window

-- find the total sales across all orders
-- and the total sales for each product
-- additionally, provide details such as orderid and order date
SELECT 
OrderID,
OrderDate,
Sales,
ProductID,
SUM(Sales) OVER() AS totalsalesacrossorders,
SUM(Sales) OVER(PARTITION BY ProductID) AS salesforeachproduct
FROM Sales.Orders

-- use case of SUM(): comparison analysis, part to whole analysis
-- find the percentage contribution of each products' sales to the total sales
SELECT
OrderID,
ProductID,
Sales,
SUM(Sales) OVER() AS totalsales,
ROUND(CAST(Sales AS Float) /SUM(Sales) OVER() *100, 2) AS percentage
FROM Sales.Orders


-- AVG() Function

-- find the average sales across all orders
-- and the average sales for each product
-- additionally, provide details such as orderid and order date
SELECT
OrderID,
OrderDate,
Sales,
ProductID,
AVG(Sales) OVER() AS avgsales,
AVG(Sales) OVER(PARTITION BY ProductID) AS averagesalesbyproduct
FROM Sales.Orders

-- find all orders where sales are higher than the average sales across all orders
SELECT 
*
FROM 
(
SELECT
    OrderID,
    OrderDate,
    Sales,
    AVG(Sales) OVER() AS avg_sales
FROM Sales.Orders
) AS t
WHERE Sales > avg_sales

-- min/max
-- find the highest and lowest sales of all orders
-- find the highest and lowest sales for each product
-- additionally, provide details such as orderid and orderdate
SELECT
    OrderID,
    OrderDate,
    ProductID,
    Sales,
    MAX(Sales) OVER() AS highestSales,
    MIN(Sales) OVER() AS lowestSales,
    MAX(Sales) OVER(PARTITION BY ProductID) AS highestSalesByProduct,
    MIN(Sales) OVER(PARTITION BY ProductID) AS lowestSalesByProduct
FROM Sales.Orders

-- show the employees who have the highest salaries
SELECT 
*
FROM 
(
    SELECT
*,
MAX(Salary) OVER() AS highestSalary
FROM Sales.Employees
) as t
WHERE highestSalary = Salary

-- calculate the deviation from each sales from both the minimum and maximum sales amount
SELECT
    OrderID,
    OrderDate,
    ProductID,
    Sales,
    MAX(Sales) OVER() AS highestSales,
    MIN(Sales) OVER() AS lowestSales,
    Sales - MIN(Sales) OVER() AS deviationFromMin,
    MAX(Sales) OVER() - Sales AS deviationFromMax
FROM Sales.Orders

-- Use case of MIN/MAX: Running Total and Rolling Total

-- calculate the moving average of sales for each product over time
SELECT 
    OrderID,
    ProductID,
    OrderDate,
    Sales,
    AVG(Sales) OVER(PARTITION BY ProductID) AS avgByProduct,
    AVG(Sales) OVER(PARTITION BY ProductID ORDER BY OrderDate) AS movingAverage
FROM Sales.Orders

-- calculate the moving average of sales for each product over time, including only the next order
SELECT 
    OrderID,
    ProductID,
    OrderDate,
    Sales,
    AVG(Sales) OVER(PARTITION BY ProductID ORDER BY OrderDate ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING) AS rollingAVG
FROM Sales.Orders