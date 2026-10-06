-- *********No Join************
-- retrieve all data from customers and orders as separate results
SELECT * FROM customers;
SELECT * FROM orders;

-- *******Inner Join********
-- get all customers along with their orders, but only for customers who have placed an order
SELECT 
    c.id, 
    c.first_name, 
    o.order_id, 
    o.sales 
FROM customers AS c
INNER JOIN orders AS o
ON c.id = o.customer_id 


-- *******Left Join*********
-- Get all customers along with their orders, including those without orders
SELECT 
    c.id, 
    c.first_name, 
    o.order_id, 
    o.sales 
FROM customers AS c
LEFT JOIN orders AS o
ON c.id = o.customer_id 


-- *******Right Join*********
-- get all customers along with their orders, including orders without matching customers
SELECT 
    c.id, 
    c.first_name, 
    o.order_id, 
    o.sales 
FROM customers AS c
RIGHT JOIN orders AS o
ON c.id = o.customer_id 
-- with left join
SELECT 
    c.id, 
    c.first_name, 
    o.order_id, 
    o.sales 
FROM orders AS o
LEFT JOIN customers AS c
ON c.id = o.customer_id 


-- *******Full Join*********
SELECT * 
FROM customers
FULL JOIN orders
ON customers.id = orders.customer_id

-- *******Left Anti Join*********
-- get all customers who have not placed an order
SELECT * 
FROM customers AS c
LEFT JOIN orders as o
ON c.id = o.customer_id
WHERE o.order_id IS NULL


-- *******Right Anti Join*********
-- get all orders without matching customers
SELECT * 
FROM customers AS c
RIGHT JOIN orders as o
ON c.id = o.customer_id
WHERE c.id IS NULL
-- with left join
SELECT * 
FROM orders AS o
LEFT JOIN customers as c
ON c.id = o.customer_id
WHERE c.id IS NULL

-- *******Full Anti Join*********
SELECT *
FROM customers AS c
FULL JOIN orders AS o   
ON c.id = o.customer_id
WHERE c.id IS NULL OR o.customer_id IS NULL

-- get all customers along with their orders, but only for customers who have placed an order, without using inner join
SELECT *
FROM customers AS c
LEFT JOIN orders as o
ON c.id = o.customer_id
WHERE o.order_id IS NOT NULL

-- ***** Cross Join*******
-- generate all possible combinations from customers and orders
SELECT *
FROM customers
CROSS JOIN orders

-- Task
-- using salesDB, retrieve a list of all orders, along with the related customers, product and employee details. 
-- For each, display:
-- order id, customer's name, product name, sales, price, sales persons's name
SELECT 
    o.OrderID,
    o.Sales,
    c.FirstName AS CustomerFirstName,
    c.LastName AS CustomerLastName,
    p.Product AS ProductName,
    p.price,
    e.FirstName AS EmployeeFirstName,
    e.LastName AS EmployeeLastName
FROM Sales.Orders AS o
LEFT JOIN Sales.Customers AS c
ON o.CustomerID = c.CustomerID
LEFT JOIN Sales.Products AS p
ON o.ProductID = p.ProductID
LEFT JOIN Sales.Employees AS e
ON o.SalesPersonID = e.EmployeeID