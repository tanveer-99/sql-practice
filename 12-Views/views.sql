-- view is a virtual table that shows data without storing it physically
-- views are persisted query on the database

-- use case: store central complex business logic to be reused

-- Use case: Views can be used to hide the complexity of database tables
-- task: provide view that combines details from orders, products, customers and employees
CREATE VIEW Sales.V_Order_Details AS
(
    SELECT
        o.OrderID,
        o.OrderDate,
        p.Product,
        p.Category,
        COALESCE(c.FirstName, '') + COALESCE(c.LastName, '') AS CustomerName,
        c.Country AS CustomerCountry,
        COALESCE(e.FirstName, '') + COALESCE(e.LastName, '') AS SalesPersonName,
        e.Department,
        o.Sales,
        o.Quantity
    FROM Sales.Orders AS o
    LEFT JOIN Sales.Products AS p
    ON o.ProductID = p.ProductID
    LEFT JOIN Sales.Customers AS c
    ON o.CustomerID = c.CustomerID
    LEFT JOIN Sales.Employees AS e
    ON o.SalesPersonID = e.EmployeeID
)

-- use case: data security, use views to enforce data security, and protect sensitive data, by hiding columns or rows from the table
-- task: provide a view for the EU sales team that combines details from all tables and excludes data related to the USA
CREATE VIEW Sales.V_Order_Details_EU AS
(
        SELECT
        o.OrderID,
        o.OrderDate,
        p.Product,
        p.Category,
        COALESCE(c.FirstName, '') + COALESCE(c.LastName, '') AS CustomerName,
        c.Country AS CustomerCountry,
        COALESCE(e.FirstName, '') + COALESCE(e.LastName, '') AS SalesPersonName,
        e.Department,
        o.Sales,
        o.Quantity
    FROM Sales.Orders AS o
    LEFT JOIN Sales.Products AS p
    ON o.ProductID = p.ProductID
    LEFT JOIN Sales.Customers AS c
    ON o.CustomerID = c.CustomerID
    LEFT JOIN Sales.Employees AS e
    ON o.SalesPersonID = e.EmployeeID   
    WHERE c.Country != 'USA'
)


-- Use case: flexibility and dynamic 

-- Use case: multiple language 

-- use case: views can be used as data marts in data warehouse system because they provide a flexible and efficient way to present data
