 -- GETDATE()
 -- return the current date and time at the moment when the query is executed
 SELECT
    OrderId,
    CreationTime,
    '2025-08-25' AS HardCoded,
    GETDATE() AS Today
FROM Sales.Orders

-- Part Extraction
-- DAY() returns the date
-- MONTH() returns the month
-- YEAR() returns the year
-- DATEPART() returns the specific part of a date as a number
-- DATENAME() returns the name of a specific part of a date
-- DATETRUNC() truncates the date to a specific part
-- EOMONTH() returns the last day of a month
SELECT 
OrderId,
CreationTime,
YEAR(creationTime) AS Year,
MONTH(CreationTime) AS Month,
DAY(CreationTime) AS Date,
DATEPART(year, CreationTime) AS year_dp,
DATEPART(month, CreationTime) AS year_dp,
DATEPART(day, CreationTime) AS year_dp,
DATEPART(hour, CreationTime) AS hour,
DATEPART(quarter, CreationTime) AS quarter,
DATEPART(WEEKDAY, CreationTime) AS weekday,
DATEPART(week, CreationTime) AS week,
DATENAME(MONTH, CreationTime) AS month_name,
DATENAME(WEEKDAY, CreationTime) AS day,
DATENAME(QUARTER, CreationTime) AS quarter,
DATENAME(WEEK, CreationTime) AS week_name,
DATETRUNC(MONTH, CreationTime) AS month_trunc,
DATETRUNC(hour, CreationTime) AS hour_trunc,
EOMONTH(CreationTime) AS eomonth
FROM Sales.Orders


-- how many orders were placed each year
SELECT 
count(*) AS No_of_Orders,
YEAR(OrderDate) AS order_year
FROM Sales.Orders
GROUP BY YEAR(OrderDate)
-- how many orders were placed each year
SELECT 
count(*) AS No_of_Orders,
DATENAME(MONTH,OrderDate) AS order_year
FROM Sales.Orders
GROUP BY DATENAME(MONTH,OrderDate)

-- show all orders that were placed during the month of february
SELECT 
*
FROM Sales.Orders
WHERE MONTH(OrderDate) = 2