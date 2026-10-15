# SQL Views

A quick reference for views in T-SQL (SQL Server): what they are, how to create and manage them, and the main use cases (hiding complexity, security, flexibility, multiple languages, data marts), plus the gotchas.

A **view** is a **virtual table** that shows data without storing it physically. It's a **persisted query**: the database saves the query definition, and every time you select from the view, it runs that query against the underlying tables.

---

## Table of Contents

- [Important Notes](#important-notes)
- [How a View Works](#how-a-view-works)
- [Sample Data](#sample-data)
- [Creating and Managing Views](#creating-and-managing-views)
- [Use Case: Hide Complexity](#use-case-hide-complexity)
- [Use Case: Data Security](#use-case-data-security)
- [Use Case: Flexibility and Dynamic Data](#use-case-flexibility-and-dynamic-data)
- [Use Case: Multiple Languages](#use-case-multiple-languages)
- [Use Case: Data Marts in a Data Warehouse](#use-case-data-marts-in-a-data-warehouse)
- [Aggregated Views](#aggregated-views)
- [Updating Data Through a View](#updating-data-through-a-view)
- [View Options](#view-options)
- [View vs CTE vs Temp Table vs Table](#view-vs-cte-vs-temp-table-vs-table)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Important Notes

1. **A view stores a query, not data.** It always shows the **current** data of the underlying tables. (The exception is an *indexed view*, which materialises results. See [View Options](#view-options).)
2. **A view doesn't make a query faster.** SQL Server expands the view definition into your query, so you pay for the joins and filters each time. Views are for **simplicity, security and consistency**, not speed.
3. **`CREATE VIEW` must be the only statement in its batch.** In SSMS or scripts, put `GO` before and after it, or you get `'CREATE VIEW' must be the first statement in a query batch`.
4. **No `ORDER BY` inside a view** unless it has `TOP` or `OFFSET`. Sort when you query the view.
5. **Name every column, and don't repeat names.** Expressions need an alias (`SUM(Sales) AS TotalSales`). Two columns called `Name` from two joined tables will fail.
6. **Avoid `SELECT *` in a view.** The column list is fixed when the view is created, so columns added to the table later don't show up, and renamed or dropped columns can break it. List columns explicitly.
7. **Views can hide columns and rows, but permissions do the real protection.** Give users access to the view and not the base tables.
8. **Simple views can be updated, complex ones can't.** Joins, aggregates, `DISTINCT` and `GROUP BY` generally make a view read-only.
9. **A view is a database object.** It needs `CREATE`/`ALTER`/`DROP`, belongs to a schema, and is shared by everyone with permission. A CTE or temp table is just for you.

---

## How a View Works

```
   Query:  SELECT * FROM Sales.V_Order_Details WHERE ...
                         │
                         ▼
   The stored definition is merged into your query
   (joins Orders + Products + Customers + Employees)
                         │
                         ▼
   Runs against the real tables → returns current data
```

|                             | Table                          | View                                        |
| --------------------------- | ------------------------------ | ------------------------------------------- |
| Stores data                 | **Yes**                  | **No** (just the query)               |
| Always current              | Holds a snapshot until updated | **Always** reflects the source tables |
| Takes disk space            | Yes                            | Only the definition                         |
| Can be queried like a table | Yes                            | Yes                                         |

---

## Sample Data

```sql
CREATE SCHEMA Sales;
GO

CREATE TABLE Sales.Products (
    ProductID INT PRIMARY KEY,
    Product   VARCHAR(50),
    Category  VARCHAR(50),
    Price     INT
);

INSERT INTO Sales.Products VALUES
(101, 'Bottle', 'Accessories', 10),
(102, 'Tire',   'Accessories', 15),
(103, 'Caps',   'Clothing',    25),
(104, 'Gloves', 'Clothing',    30),
(105, 'Helmet', 'Clothing',    30);

CREATE TABLE Sales.Customers (
    CustomerID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    LastName   VARCHAR(50),
    Country    VARCHAR(50) NULL
);

INSERT INTO Sales.Customers VALUES
(1, 'Jossef', 'Goldberg', 'Germany'),
(2, 'Kevin',  'Brown',    'USA'),
(3, 'Mary',   'Dury',     'France'),
(4, 'Mark',   'Schwarz',  'India'),
(5, 'Anna',   'Adams',    NULL);          -- country unknown

CREATE TABLE Sales.Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    LastName   VARCHAR(50),
    Department VARCHAR(50)
);

INSERT INTO Sales.Employees VALUES
(1, 'Frank',   'Lee',   'Sales'),
(2, 'Michael', 'Ray',   'Marketing'),
(3, 'Carol',   'Baker', 'Sales');

CREATE TABLE Sales.Orders (
    OrderID       INT PRIMARY KEY,
    ProductID     INT,
    CustomerID    INT NULL,
    SalesPersonID INT NULL,
    OrderDate     DATE,
    Sales         INT,
    Quantity      INT
);

INSERT INTO Sales.Orders VALUES
(1, 101, 1,    1,    '2025-01-01', 10, 2),
(2, 102, 2,    2,    '2025-01-05', 15, 1),
(3, 103, 3,    1,    '2025-01-10', 25, 1),
(4, 104, 4,    3,    '2025-01-20', 60, 2),
(5, 105, 5,    2,    '2025-02-01', 30, 1),
(6, 101, 2,    3,    '2025-02-05', 20, 2),
(7, 102, NULL, 1,    '2025-02-10', 40, 4),   -- order with no customer
(8, 103, 1,    NULL, '2025-02-15', 90, 3);   -- order with no salesperson
```

The sample deliberately includes an order with **no customer**, an order with **no salesperson**, and a customer with an **unknown country**. These show where views (and `WHERE` filters inside them) can silently lose or keep rows.

---

## Creating and Managing Views

```sql
-- create
CREATE VIEW Sales.V_Name AS
SELECT col1, col2
FROM Sales.SomeTable
WHERE ...;
GO

-- change the definition
ALTER VIEW Sales.V_Name AS
SELECT col1, col2, col3
FROM Sales.SomeTable;
GO

-- create or replace in one go (SQL Server 2016 SP1+)
CREATE OR ALTER VIEW Sales.V_Name AS
SELECT ...;
GO

-- delete
DROP VIEW Sales.V_Name;
DROP VIEW IF EXISTS Sales.V_Name;      -- SQL Server 2016+
```

**Older-style "drop if exists":**

```sql
IF OBJECT_ID('Sales.V_Name', 'V') IS NOT NULL
    DROP VIEW Sales.V_Name;
GO
```

**Use a view exactly like a table:**

```sql
SELECT * FROM Sales.V_Order_Details WHERE Sales > 20;
SELECT Product, SUM(Sales) FROM Sales.V_Order_Details GROUP BY Product;
```

**Find views and their definitions:**

```sql
SELECT name FROM sys.views;                                 -- list views
SELECT * FROM INFORMATION_SCHEMA.VIEWS;                     -- with definitions
SELECT OBJECT_DEFINITION(OBJECT_ID('Sales.V_Order_Details'));
```

**Refresh after the underlying table changes** (only needed if the view uses `SELECT *`):

```sql
EXEC sp_refreshview 'Sales.V_Name';
```

> Wrapping the `SELECT` in parentheses (`AS ( SELECT ... )`) is allowed but unnecessary.

---

# Use Case: Hide Complexity

Views can hide complicated joins so users don't have to know how the tables fit together.

**Task:** provide a view that combines details from orders, products, customers and employees.

```sql
CREATE VIEW Sales.V_Order_Details AS
SELECT
    o.OrderID,
    o.OrderDate,
    p.Product,
    p.Category,
    TRIM(CONCAT(c.FirstName, ' ', c.LastName))  AS CustomerName,
    c.Country                                   AS CustomerCountry,
    TRIM(CONCAT(e.FirstName, ' ', e.LastName))  AS SalesPersonName,
    e.Department,
    o.Sales,
    o.Quantity
FROM Sales.Orders AS o
LEFT JOIN Sales.Products  AS p ON o.ProductID     = p.ProductID
LEFT JOIN Sales.Customers AS c ON o.CustomerID    = c.CustomerID
LEFT JOIN Sales.Employees AS e ON o.SalesPersonID = e.EmployeeID;
GO
```

```sql
SELECT * FROM Sales.V_Order_Details;
```

| OrderID | OrderDate  | Product | Category    | CustomerName    | CustomerCountry | SalesPersonName | Department | Sales | Quantity |
| ------- | ---------- | ------- | ----------- | --------------- | --------------- | --------------- | ---------- | ----- | -------- |
| 1       | 2025-01-01 | Bottle  | Accessories | Jossef Goldberg | Germany         | Frank Lee       | Sales      | 10    | 2        |
| 2       | 2025-01-05 | Tire    | Accessories | Kevin Brown     | USA             | Michael Ray     | Marketing  | 15    | 1        |
| 3       | 2025-01-10 | Caps    | Clothing    | Mary Dury       | France          | Frank Lee       | Sales      | 25    | 1        |
| 4       | 2025-01-20 | Gloves  | Clothing    | Mark Schwarz    | India           | Carol Baker     | Sales      | 60    | 2        |
| 5       | 2025-02-01 | Helmet  | Clothing    | Anna Adams      | NULL            | Michael Ray     | Marketing  | 30    | 1        |
| 6       | 2025-02-05 | Bottle  | Accessories | Kevin Brown     | USA             | Carol Baker     | Sales      | 20    | 2        |
| 7       | 2025-02-10 | Tire    | Accessories | *(empty)*     | NULL            | Frank Lee       | Sales      | 40    | 4        |
| 8       | 2025-02-15 | Caps    | Clothing    | Jossef Goldberg | Germany         | *(empty)*     | NULL       | 90    | 3        |

Now anyone can run `SELECT ... FROM Sales.V_Order_Details` without writing the four-table join, and if the join logic changes, you fix it in one place.

**Notes on the query:**

- **`LEFT JOIN` from `Orders`** keeps every order, even ones with no matching customer, product or salesperson (orders 7 and 8). An `INNER JOIN` would drop them silently.
- **Name concatenation.** `COALESCE(FirstName, '') + COALESCE(LastName, '')` runs the names together (`JossefGoldberg`) because there's no space between them. `TRIM(CONCAT(FirstName, ' ', LastName))` adds the space, treats `NULL` as empty, and trims the stray space when one part is missing. `TRIM` needs SQL Server 2017+. On older versions use `LTRIM(RTRIM(...))`.
- **Missing names show as an empty string.** If you'd rather see a label, wrap it: `COALESCE(NULLIF(TRIM(CONCAT(...)), ''), 'Unknown')`.
- **Column aliases** (`CustomerCountry`, `SalesPersonName`) make the view self-explanatory. Both `c.Country` and `e.Department` have clear names, and there are no duplicate column names.

---

# Use Case: Data Security

Views can **hide columns or rows** from a table, so people only see what they're meant to see.

**Task:** provide a view for the EU sales team that combines details from all tables and excludes data related to the USA.

### First attempt (and why it's risky)

```sql
CREATE VIEW Sales.V_Order_Details_EU AS
SELECT
    o.OrderID, o.OrderDate, p.Product, p.Category,
    TRIM(CONCAT(c.FirstName, ' ', c.LastName)) AS CustomerName,
    c.Country AS CustomerCountry,
    TRIM(CONCAT(e.FirstName, ' ', e.LastName)) AS SalesPersonName,
    e.Department, o.Sales, o.Quantity
FROM Sales.Orders AS o
LEFT JOIN Sales.Products  AS p ON o.ProductID     = p.ProductID
LEFT JOIN Sales.Customers AS c ON o.CustomerID    = c.CustomerID
LEFT JOIN Sales.Employees AS e ON o.SalesPersonID = e.EmployeeID
WHERE c.Country != 'USA';
GO
```

```sql
SELECT OrderID, CustomerName, CustomerCountry, Sales FROM Sales.V_Order_Details_EU;
```

| OrderID | CustomerName    | CustomerCountry | Sales |
| ------- | --------------- | --------------- | ----- |
| 1       | Jossef Goldberg | Germany         | 10    |
| 3       | Mary Dury       | France          | 25    |
| 4       | Mark Schwarz    | **India** | 60    |
| 8       | Jossef Goldberg | Germany         | 90    |

**Two problems:**

1. **"Not USA" isn't "EU".** India is in the result. Any non-EU country (India, UK, Japan, ...) slips into the EU team's view.
2. **`NULL` countries silently vanish.** `NULL != 'USA'` is UNKNOWN, not true, so orders 5 (unknown country) and 7 (no customer) are dropped. This also defeats the purpose of the `LEFT JOIN`.

### Better: filter on the countries you actually want

```sql
CREATE VIEW Sales.V_Order_Details_EU AS
SELECT
    OrderID, OrderDate, Product, Category,
    CustomerName, CustomerCountry, SalesPersonName, Department, Sales, Quantity
FROM Sales.V_Order_Details
WHERE CustomerCountry IN ('Germany', 'France', 'Italy', 'Spain', 'Netherlands' /* ... */);
GO
```

| OrderID | CustomerName    | CustomerCountry | Sales |
| ------- | --------------- | --------------- | ----- |
| 1       | Jossef Goldberg | Germany         | 10    |
| 3       | Mary Dury       | France          | 25    |
| 8       | Jossef Goldberg | Germany         | 90    |

- For a real system, keep a **country-to-region lookup table** and join to it, instead of hard-coding a list.
- If you do want to **exclude only the USA** and keep rows with unknown country, handle the `NULL` explicitly: `WHERE COALESCE(c.Country, '') <> 'USA'` (this returns orders 1, 3, 4, 5, 7, 8).
- A view can be built **on top of another view** (as above), so the security view reuses the join logic. Deep stacks of views get hard to debug and can be slow, so keep the nesting shallow.

### Making the security real: permissions

A view only protects data if users **can't query the base tables**:

```sql
-- the EU team reads only the view
GRANT SELECT ON Sales.V_Order_Details_EU TO EU_Sales_Team;
DENY  SELECT ON Sales.Orders             TO EU_Sales_Team;
DENY  SELECT ON Sales.Customers          TO EU_Sales_Team;
```

Because the view and tables are in the same schema (same owner), SQL Server's **ownership chaining** lets the user read through the view without needing rights on the underlying tables.

**Limits of view-based security:**

- It's fine for hiding columns and filtering rows by a fixed rule. For rules that depend on the **logged-in user**, SQL Server's **Row-Level Security** is stronger.
- Anyone with `VIEW DEFINITION` can read the view's SQL.
- Hiding a column in a view only protects it if the base table is locked down too.

---

# Use Case: Flexibility and Dynamic Data

A view is an **abstraction layer** between the tables and whoever consumes them (reports, apps, analysts).

**Always current:** because a view stores no data, it automatically shows new and changed rows. There's nothing to refresh.

**Absorbs changes in the tables.** If the table structure changes, you update the **view definition once**, and every report keeps working:

```sql
-- the Sales column was renamed to SalesAmount in the table;
-- the view keeps the old name for consumers
CREATE OR ALTER VIEW Sales.V_Order_Details AS
SELECT
    o.OrderID,
    o.SalesAmount AS Sales,        -- consumers still see "Sales"
    ...
```

The same works when a table is split in two, a column is renamed, or a data type changes. The view keeps presenting the same shape.

**Reuse and consistency:** business logic such as "net sales", "customer segment" or "active customer" lives in one place. Every report calculates it the same way, instead of each report author rewriting (and subtly changing) it.

---

# Use Case: Multiple Languages

Views can present the same data in different languages: translated column names for each team, and (with a lookup table) translated values.

**Translated column names** via aliases:

```sql
CREATE VIEW Sales.V_Orders_DE AS
SELECT
    OrderID         AS Bestellnummer,
    OrderDate       AS Bestelldatum,
    Product         AS Produkt,
    CustomerName    AS Kundenname,
    Sales           AS Umsatz,
    Quantity        AS Menge
FROM Sales.V_Order_Details;
GO

CREATE VIEW Sales.V_Orders_FR AS
SELECT
    OrderID         AS NumeroCommande,
    OrderDate       AS DateCommande,
    Product         AS Produit,
    CustomerName    AS NomClient,
    Sales           AS Ventes,
    Quantity        AS Quantite
FROM Sales.V_Order_Details;
GO
```

Each team queries the view in its own language, while the underlying data and logic stay the same.

**Translated values** (for example category names) come from a translation table joined inside the view:

```sql
CREATE TABLE Sales.CategoryTranslation (
    Category     VARCHAR(50),
    LanguageCode CHAR(2),
    Translation  VARCHAR(50)
);

CREATE VIEW Sales.V_Products_DE AS
SELECT
    p.ProductID,
    p.Product      AS Produkt,
    t.Translation  AS Kategorie
FROM Sales.Products AS p
LEFT JOIN Sales.CategoryTranslation AS t
    ON t.Category = p.Category AND t.LanguageCode = 'DE';
GO
```

---

# Use Case: Data Marts in a Data Warehouse

In a data warehouse, views are a flexible and efficient way to present data as **data marts**: subject-focused slices (sales, finance, HR) built on top of the central warehouse tables.

```sql
-- a small sales data mart: one fact view, two dimension views
CREATE SCHEMA Mart_Sales;
GO

CREATE VIEW Mart_Sales.V_Fact_Orders AS
SELECT OrderID, OrderDate, ProductID, CustomerID, SalesPersonID, Sales, Quantity
FROM Sales.Orders;
GO

CREATE VIEW Mart_Sales.V_Dim_Customer AS
SELECT CustomerID, TRIM(CONCAT(FirstName, ' ', LastName)) AS CustomerName, Country
FROM Sales.Customers;
GO

CREATE VIEW Mart_Sales.V_Dim_Product AS
SELECT ProductID, Product, Category
FROM Sales.Products;
GO
```

Why views work well here:

- **No duplicated data.** The mart is just definitions on top of the warehouse.
- **Tailored per audience.** Each mart exposes only the tables and columns that team needs.
- **Easy to change.** Add a column or change a calculation by altering the view.
- **A stable interface** for BI tools. Underlying tables can be reorganised without breaking dashboards.

If a mart view is too slow because of heavy joins or aggregation, consider an **indexed view** or a physical table loaded on a schedule.

---

# Aggregated Views

Views can summarise data, which is handy for reporting.

```sql
CREATE VIEW Sales.V_Monthly_Summary AS
SELECT
    DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS OrderMonth,
    SUM(Sales)       AS TotalSales,
    SUM(Quantity)    AS TotalQuantity,
    COUNT(OrderID)   AS TotalOrders
FROM Sales.Orders
GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1);
GO

SELECT * FROM Sales.V_Monthly_Summary ORDER BY OrderMonth;
```

| OrderMonth | TotalSales | TotalQuantity | TotalOrders |
| ---------- | ---------- | ------------- | ----------- |
| 2025-01-01 | 110        | 6             | 4           |
| 2025-02-01 | 180        | 10            | 4           |

- Every expression has an alias (a requirement).
- The `ORDER BY` is on the query, not in the view definition.
- Aggregated views are **read-only**, and the aggregation runs every time you query them.

---

# Updating Data Through a View

A view that selects from a **single table** with no aggregates, `DISTINCT` or `GROUP BY` can usually be used with `INSERT`/`UPDATE`/`DELETE`, and the change goes to the underlying table.

```sql
CREATE VIEW Sales.V_Customers_Germany AS
SELECT CustomerID, FirstName, LastName, Country
FROM Sales.Customers
WHERE Country = 'Germany'
WITH CHECK OPTION;
GO

UPDATE Sales.V_Customers_Germany SET LastName = 'Smith' WHERE CustomerID = 1;   -- works
UPDATE Sales.V_Customers_Germany SET Country = 'USA'    WHERE CustomerID = 1;   -- fails
```

- **`WITH CHECK OPTION`** makes sure changes made **through** the view still satisfy its `WHERE`. The second update would move the row out of the view, so it's rejected. Without the option it would succeed and the row would disappear from the view.
- Views with joins, aggregates, `DISTINCT`, `GROUP BY` or `UNION` are generally **not updatable**. The multi-table views above are for reading.

---

# View Options

| Option                 | What it does                                                                                                                                                                                                 |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `WITH SCHEMABINDING` | Locks the view to the tables it uses. You can't drop or alter those tables in a way that would break the view. Required for indexed views. Needs two-part names (`Sales.Orders`) and explicit column lists |
| `WITH CHECK OPTION`  | Ensures`INSERT`/`UPDATE` through the view obey its `WHERE` clause                                                                                                                                      |
| `WITH ENCRYPTION`    | Obfuscates the view's SQL text. Weak protection, and it makes maintenance harder                                                                                                                             |

**Indexed (materialised) views:** with `WITH SCHEMABINDING` plus a **unique clustered index**, SQL Server physically stores the view's results and keeps them up to date automatically. This **can** make heavy aggregations much faster, at the cost of slower writes to the base tables. Restrictions apply: no outer joins, no `DISTINCT`, no self-joins, and more. So the `LEFT JOIN` views above can't be indexed.

```sql
CREATE VIEW Sales.V_Sales_By_Product
WITH SCHEMABINDING AS
SELECT
    ProductID,
    SUM(Sales)     AS TotalSales,
    COUNT_BIG(*)   AS RowCnt          -- required with GROUP BY in indexed views
FROM Sales.Orders
GROUP BY ProductID;
GO

CREATE UNIQUE CLUSTERED INDEX IX_V_Sales_By_Product ON Sales.V_Sales_By_Product (ProductID);
```

(`SUM` over a nullable column also needs `ISNULL` in an indexed view. This example assumes `Sales` isn't nullable.)

---

# View vs CTE vs Temp Table vs Table

|                                         | View                                  | CTE                             | Temp table (`#t`)                           | Table                        |
| --------------------------------------- | ------------------------------------- | ------------------------------- | --------------------------------------------- | ---------------------------- |
| **Stores data**                   | No                                    | No                              | **Yes**                                 | **Yes**                |
| **Lifetime**                      | Permanent (until dropped)             | One statement                   | Session                                       | Permanent                    |
| **Always current**                | **Yes**                         | Yes                             | Snapshot                                      | Snapshot                     |
| **Shared by other users/queries** | **Yes**                         | No                              | No                                            | Yes                          |
| **Can be indexed**                | Only as an indexed view               | No                              | Yes                                           | Yes                          |
| **Needs a stored object**         | Yes                                   | No                              | Creates one (temporary)                       | Yes                          |
| **Best for**                      | Reusable query, security, abstraction | Step-by-step logic in one query | Reusing an expensive result across statements | Persisted, loaded data (ETL) |

**Rules of thumb:**

- Same query used by many people or reports? **View.**
- One-off, multi-step logic? **CTE.**
- Heavy result needed repeatedly in one session? **Temp table.**
- Result must be fast and doesn't need to be live? **Physical table**, loaded on a schedule (`SELECT ... INTO`, ETL).

---

## Common Gotchas

1. **`CREATE VIEW` must be first in its batch.** Use `GO` before and after it.
2. **No `ORDER BY`** in the view. Sort when you query it, or add `TOP`/`OFFSET` (which makes the order only partly meaningful).
3. **`SELECT *` freezes the column list.** New table columns don't appear until you alter or refresh the view, and dropped columns can break it. List columns explicitly.
4. **A `WHERE` on a left-joined table silently drops rows.** `WHERE c.Country != 'USA'` removes rows where the country is `NULL` and turns the `LEFT JOIN` into an inner join. Handle `NULL` explicitly.
5. **"Not USA" is not "EU".** Filter on the values you actually want, ideally from a lookup table.
6. **Views aren't faster.** The definition is expanded into your query each time. Don't expect a speed-up, and be careful with views built on views.
7. **Unnamed or duplicate columns.** Alias expressions, and don't select two columns with the same name.
8. **A view doesn't secure the table by itself.** Grant access to the view and deny it on the base tables.
9. **Most multi-table views are read-only.** Don't try to `UPDATE` through joins or aggregates.
10. **Dependencies can break.** Dropping or renaming a table or column breaks views that use it. `SCHEMABINDING` prevents that, at the cost of flexibility.
11. **Run-together names.** `FirstName + LastName` has no space. Use `CONCAT(FirstName, ' ', LastName)`.

---

## Cheat Sheet

| I want...                                | Use                                                                |
| ---------------------------------------- | ------------------------------------------------------------------ |
| Create a view                            | `CREATE VIEW Sales.V_Name AS SELECT ...` (with `GO` around it) |
| Change a view                            | `ALTER VIEW ...` or `CREATE OR ALTER VIEW ...`                 |
| Delete a view                            | `DROP VIEW IF EXISTS Sales.V_Name`                               |
| Use a view                               | `SELECT ... FROM Sales.V_Name` (like a table)                    |
| Hide complicated joins                   | A view with the joins inside                                       |
| Hide columns                             | Select only the allowed columns in the view                        |
| Hide rows                                | `WHERE` in the view (and handle `NULL`s)                       |
| Real access control                      | `GRANT SELECT` on the view, `DENY` on the base tables          |
| Keep changes within the view's filter    | `WITH CHECK OPTION`                                              |
| Stop base tables changing under the view | `WITH SCHEMABINDING`                                             |
| Speed up a heavy aggregate               | Indexed view (`SCHEMABINDING` + unique clustered index)          |
| Different languages for different teams  | One view per language with translated aliases                      |
| See a view's SQL                         | `OBJECT_DEFINITION(OBJECT_ID('schema.view'))`                    |
| List all views                           | `SELECT name FROM sys.views`                                     |

| Use case           | Why a view helps                                  |
| ------------------ | ------------------------------------------------- |
| Hide complexity    | Users query one object, not four joined tables    |
| Data security      | Expose only the allowed rows and columns          |
| Flexibility        | Table changes are absorbed in the view definition |
| Multiple languages | Same data, different aliases or translations      |
| Data marts         | A flexible presentation layer over the warehouse  |
