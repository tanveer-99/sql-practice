-- value functions give access to a value from other row
-- functions: LEAD, LAG, FIRST_VALUE, LAST_VALUE
-- LAG() gives access to values from the previous rows within a window
-- LEAD() returns the value from the next row within a window
-- use case: time-series analysis (year-over-year or month-over-month, in businesses)
-- analyse the month-over-month performance by finding the percentage change in sales
-- between the current and previous month
SELECT
*,
current_month_sale - previous_month_sales AS MoM_change,
ROUND(CAST((current_month_sale - previous_month_sales) AS Float) / previous_month_sales * 100, 1) AS percentage
FROM 
(
    SELECT
    MONTH(OrderDate) AS month_number,
    DATENAME(MONTH, OrderDate) AS order_month,
    SUM(Sales) AS current_month_sale,
    LAG(SUM(Sales)) OVER(ORDER BY MONTH(OrderDate))AS previous_month_sales
FROM Sales.Orders
GROUP BY MONTH(OrderDate),DATENAME(MONTH, OrderDate)
) AS t
ORDER BY month_number

-- use case: customer retention analysis
-- in order to analyse customer loyalty
-- rank customers based on the average number of days between orders
SELECT
CustomerID,
AVG(order_gap) AS avgDays,
RANK() OVER(ORDER BY COALESCE(AVG(order_gap), 99999)) AS rank_avg
FROM 
(
    SELECT
    CustomerID,
    OrderID,
    OrderDate,
    LEAD(OrderDate) OVER(PARTITION BY CustomerID ORDER BY OrderDate) AS next_order_date,
    DATEDIFF(DAY, OrderDate, LEAD(OrderDate) OVER(PARTITION BY CustomerID ORDER BY OrderDate))  AS order_gap
FROM Sales.Orders
) AS t
GROUP BY CustomerID


-- FIRST_VALUE(), access a value from the first row within a window
-- LAST_VALUE(), access a value from the last row within a window

