-- common table expression is a temporary, named result set (virtual table) that can be used multiple times within the query
-- CTE rule: you cannot sort the query as ORDER BY in the CTE
-- CTE types
-- none-recursive CTE: is executed only once without any repetition: standalone CTE, Nested CTE
-- recursive CTE: self-referencing query that repeatedly processes data until a specific condition is met

-- standalone CTE: defined and used independently
-- nested CTE: a nested CTE uses the result of another CTE, so it cannot run independently  


-- step 1: find the total sales per customer
WITH CTE_total_sales AS
(
SELECT
    CustomerID,
    SUM(Sales) AS total_sales
FROM Sales.Orders
GROUP BY CustomerID
),
-- step 2: find the last order date per customer
CTE_last_order AS 
(
    SELECT
        CustomerID,
        MAX(OrderDate) AS last_order
    FROM Sales.Orders
    GROUP BY CustomerID
),
-- rank customers based on total sales per customer
CTE_customer_rank AS 
(
    SELECT
        CustomerID,
        total_sales,
        RANK() OVER(ORDER BY total_sales DESC) AS customer_rank
    FROM CTE_total_sales
),
-- segment the customers based on their total sales (Nested CTE)
CTE_customer_segment AS
(
    SELECT
        CustomerID,
        CASE WHEN total_sales>100 THEN 'High'
            WHEN total_sales>80 THEN 'Medium'
            ELSE 'Low'
        END customer_segments
    FROM CTE_total_sales
)
-- main query
SELECT
    c.CustomerID,
    c.FirstName,
    c.LastName,
    cts.total_sales,
    clo.last_order,
    ctr.customer_rank,
    ccs.customer_segments
FROM Sales.Customers AS c
LEFT JOIN CTE_total_sales AS cts
ON cts.CustomerID = c.CustomerID
LEFT JOIN CTE_last_order AS clo
ON clo.CustomerID = c.CustomerID
LEFT JOIN CTE_customer_rank AS ctr
ON ctr.CustomerID = c.CustomerID
LEFT JOIN CTE_customer_segment AS ccs
ON ccs.CustomerID = c.CustomerID
