-- evalutes a list of conditions and returns a value when the first condition is met
-- main purpose is data transformation
-- derive new information, create new columns based on the existing database
-- categorizing data

-- generate a report showing the total sales for each cateogry:
-- high: if the sale is higher than 50
-- medium: if the sale is between 20 and 50
-- low: if the sale is equal to less than 20
SELECT
cateogry,
SUM(Sales) AS total_sales
FROM
(SELECT
OrderID,
Sales,
CASE 
    WHEN Sales > 50 THEN 'High'
    WHEN Sales > 20 THEN 'Medium'
    ELSE 'Low'
END AS cateogry
FROM Sales.Orders) t
GROUP BY cateogry
ORDER BY total_sales DESC

-- RULE: the data type of the results of CASE WHEN, must be matching

-- Mapping Values:
-- transform the values from one form to another
-- retrieve employye details with gender displayed as full text
SELECT
EmployeeID,
FirstName,
LastName,
Gender,
CASE 
    WHEN Gender = 'F' THEN 'Female'
    WHEN Gender = 'M' THEN 'Male'
    ELSE 'Not Available'
END AS Gender_full_text
FROM Sales.Employees

-- use case: handling nulls, replace nulls with a specific value
-- find the average scores of customers and treat nulls as 0
SELECT 
CustomerID,
LastName,
Score,
AVG(CASE WHEN Score IS NULL THEN 0
ELSE Score
END) OVER() Avg_score
FROM Sales.Customers

-- count how many times each customer has made an order with sales greater than 30
SELECT
CustomerID,
SUM(CASE WHEN Sales > 30 THEN 1 ELSE 0 END) AS total_orders
FROM Sales.Orders
GROUP BY CustomerID
