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


-- show creationtime using the following format:
-- Day Wed Jan Q1 2025 12:34:56 PM
SELECT
OrderID,
CreationTime,
'Day ' + FORMAT(CreationTime, 'ddd MMM') + ' Q' + DATENAME(QUARTER, CreationTime) + ' '
+ FORMAT(CreationTime, 'yyyy hh:mm:ss tt')    custom_format
FROM Sales.Orders

-- cast
-- format vs convert vs cast

-- DATEADD() adds or subtracts a specific time or interval to/from a date
SELECT 
OrderID,
OrderDate,
DATEADD(day, -10, OrderDate) AS ten_days_later,
DATEADD(month, 3, OrderDate) AS three_months_later,
DATEADD(year, 2, OrderDate) AS two_years_later
FROM Sales.Orders

-- DATEDIFF() finds the differences between two dates
-- calculate the age of employees
SELECT 
EmployeeID,
BirthDate,
GETDATE() AS today,
DATEDIFF(year, BirthDate, GETDATE()) AS age
FROM Sales.Employees

-- find the average shipping duration in days for each month
SELECT

DATENAME(month,OrderDate) AS order_month,
AVG(DATEDIFF(DAY, OrderDate, ShipDate)) AS avg_shipping_time 
FROM Sales.orders
GROUP BY DATENAME(month,OrderDate)

-- time gap analysis
-- find the number of days between each order and previous order
SELECT 
OrderID,
OrderDate AS current_order_date,
LAG(OrderDate) OVER (ORDER BY OrderDate) previous_order_date,
DATEDIFF(day, LAG(OrderDate) OVER (ORDER BY OrderDate), OrderDate) AS no_of_days
FROM Sales.Orders

-- ISDATE() checks if a value is a date
-- returns 0 and 1
