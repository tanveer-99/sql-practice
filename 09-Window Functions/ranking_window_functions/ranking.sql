-- interger based ranking
-- ranks the rows with distinct numbers from 1 to N
-- functions: ROW_NUMBER(), RANK(), DENSE_RANK(), NTILE()

-- ROW_NUMBER(), assigns an unique number to each row
-- rank the orders based on their sales in descending
SELECT
OrderID,
ProductID,
Sales,
ROW_NUMBER() OVER(ORDER BY Sales DESC) AS salesrank_row
FROM Sales.Orders
-- RANK(), assign a rank to each row, handles ties, it leaves gaps in ranking, multiple rows can share the same number, but the chronology of numbers will be ordered
-- rank the orders based on their sales in descending
SELECT
OrderID,
ProductID,
Sales,
ROW_NUMBER() OVER(ORDER BY Sales DESC) AS salesrank_row,
RANK() OVER(ORDER BY Sales DESC) AS salesrank
FROM Sales.Orders
-- DENSE_RANK(), assigns a rank to each row, handles ties, but it doesn't leave gaps in ranking, shared ranking
-- rank the orders based on their sales in descending
SELECT
OrderID,
ProductID,
Sales,
DENSE_RANK() OVER(ORDER BY Sales DESC) AS sales_dense_rank
FROM Sales.Orders

-- USE CASE: Top N analysis
-- find the top highest sales for each product
SELECT *
FROM
(
    SELECT
OrderID,
ProductID,
Sales,
ROW_NUMBER() OVER(PARTITION BY ProductID ORDER BY Sales DESC) AS rank_by_product
FROM Sales.Orders
) AS t
WHERE rank_by_product = 1
-- use case: bottom n analysis
-- helps analyse underperformance to manage risks and to do optimizations

-- use case: assign unique ids
-- help to assign unique identifier for each row to help paginating,
-- the process of breaking down a large data into smaller, more manageable chunks
-- assign unique ids to the rows of the table orders archive 
SELECT
ROW_NUMBER() OVER(ORDER BY OrderID, OrderDate) AS uniqueID, 
*
FROM Sales.OrdersArchive

-- use case: identify duplicates
-- identify duplicate rows in the table 'orders archive' and return a clean result without any duplicates
SELECT
*
FROM 
(
    SELECT
ROW_NUMBER() OVER(PARTITION BY OrderID ORDER BY CreationTime DESC) AS rn,
*
FROM Sales.OrdersArchive
) AS t
WHERE rn = 1

-- NTILE(), divides the rows into a specified number of approximately equal groups(bucket)
-- use case: data segmentation: as data analyst
-- segment all orders into 3 categories: high, medium and low
SELECT
*,
CASE WHEN bucket = 1 THEN 'High'
    WHEN bucket = 2 THEN 'Medium'
    WHEN bucket = 3 THEN 'Low'
END AS sales_segments
FROM
(
    SELECT
OrderID,
Sales,
NTILE(3) OVER(ORDER BY Sales DESC) AS bucket
FROM Sales.Orders
) AS t

-- use case: equalizing load processing (ETL) and load balancing as data engineer
-- when transferring data from one place to another, their might be issues because of different factors
-- so splitting the data into small buckets will allow us to ship the data properly and efficiently
-- and at the end, UNION them all




--percentage based ranking
-- finds the distribution of the row/product 
-- Functions: CUME_DIST(), PERCENT_RANK()
-- CUME_DIST() calculates the distribution of data points within a window, inclusive, current row is included
-- PERCENT_RANK() calculates the relative position of each row within a window, exclusive, current row is excluded

-- find the product that fall within the highest 40% of the prices
SELECT
*,
CONCAT(dist_rank * 100, '%') AS distrankpercentage
FROM 
(
    SELECT
Product,
Price,
CUME_DIST() OVER(ORDER BY Price DESC) AS dist_rank
FROM Sales.Products
) AS t
WHERE dist_rank <=0.4



