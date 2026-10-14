
# SQL Common Table Expressions (CTE)

A quick reference for CTEs in T-SQL (SQL Server): standalone, nested and recursive CTEs, the rules that trip people up, and how CTEs compare with subqueries and temp tables.

A **CTE (common table expression)** is a **temporary, named result set** (a virtual table) that exists only for the duration of **one statement**. You define it once at the top with `WITH`, then use it like a table, and can refer to it more than once in that statement.

---

## Table of Contents

- [Important Notes](#important-notes)
- [Syntax](#syntax)
- [CTE Types](#cte-types)
- [Sample Data](#sample-data)
- [Non-Recursive CTEs](#non-recursive-cte)
  - [Standalone CTE](#standalone-cte) · [Nested CTE](#nested-cte) · [Full example](#full-example-customer-report)
- [Recursive CTEs](#recursive-cte)
  - [Generate a number series](#example-generate-a-number-series) · [Employee hierarchy](#example-employee-hierarchy) · [Date series](#example-generate-a-date-series) · [Limits and MAXRECURSION](#recursion-limit-and-maxrecursion)
- [CTE vs Subquery vs Temp Table vs View](#cte-vs-subquery-vs-temp-table-vs-view)
- [CTEs With INSERT, UPDATE and DELETE](#ctes-with-insert-update-and-delete)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Important Notes

1. **A CTE lives for one statement only.** Once the `SELECT`/`INSERT`/`UPDATE`/`DELETE` that follows it finishes, the CTE is gone. To reuse the result in a later statement, use a temp table.
2. **A CTE is not stored or cached.** In SQL Server it's essentially a named query that's re-evaluated **each time you reference it**. Referencing an expensive CTE three times can run it three times.
3. **No `ORDER BY` inside a CTE** (unless it also has `TOP`, `OFFSET` or `FOR XML`). Sort in the final query instead.
4. **One `WITH`, many CTEs.** Separate multiple CTEs with commas. A later CTE can use any **earlier** one, never a later one.
5. **If `WITH` isn't the first statement in the batch, the previous statement must end with a semicolon.** Otherwise: `Incorrect syntax near the keyword 'WITH'`. The common habit is to write `;WITH`.
6. **Every column needs a name.** Give expressions an alias (`SUM(Sales) AS total_sales`), or list the column names after the CTE name.
7. **Recursive CTEs need two parts joined by `UNION ALL`:** an anchor (the starting rows) and a recursive member (which refers to the CTE itself). SQL Server stops after **100 levels** by default.
8. **The main query must come right after the CTEs.** You can't put another statement in between.

---

## Syntax

```sql
WITH cte_name AS (
    SELECT ...            -- the query that defines the CTE
)
SELECT *
FROM cte_name;            -- the main query uses it like a table
```

**With a column list:**

```sql
WITH cte_name (customer_id, total) AS (
    SELECT CustomerID, SUM(Sales)
    FROM Sales.Orders
    GROUP BY CustomerID
)
SELECT * FROM cte_name;
```

**Several CTEs:**

```sql
WITH cte_one AS (
    SELECT ...
),
cte_two AS (
    SELECT ... FROM cte_one      -- can use cte_one
)
SELECT ... FROM cte_two;
```

Comments can sit between CTEs. There's no `WITH` before the second CTE, only a comma.

---

## CTE Types

| Type                    | What it does                                                                              |
| ----------------------- | ----------------------------------------------------------------------------------------- |
| **Non-recursive** | Runs once, with no repetition                                                             |
| ↳**Standalone**  | Defined and used independently. It doesn't depend on any other CTE                        |
| ↳**Nested**      | Uses the result of**another CTE**, so it can't run on its own                       |
| **Recursive**     | A**self-referencing** query that repeatedly processes data until a condition is met |

---

## Sample Data

```sql
CREATE SCHEMA Sales;
GO

CREATE TABLE Sales.Customers (
    CustomerID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    LastName   VARCHAR(50)
);

INSERT INTO Sales.Customers VALUES
(1, 'Jossef', 'Goldberg'),
(2, 'Kevin',  'Brown'),
(3, 'Mary',   'Dury'),
(4, 'Mark',   'Schwarz'),
(5, 'Anna',   'Adams');          -- has no orders

CREATE TABLE Sales.Orders (
    OrderID     INT PRIMARY KEY,
    ProductID   INT,
    CustomerID  INT,
    OrderDate   DATE,
    OrderStatus VARCHAR(20),
    Sales       INT
);

INSERT INTO Sales.Orders VALUES
(1,  101, 2, '2025-01-01', 'Delivered', 10),
(2,  102, 3, '2025-01-05', 'Shipped',   15),
(3,  101, 1, '2025-01-10', 'Delivered', 20),
(4,  105, 1, '2025-01-20', 'Shipped',   60),
(5,  104, 2, '2025-02-01', 'Delivered', 25),
(6,  104, 3, '2025-02-05', 'Shipped',   50),
(7,  102, 1, '2025-02-10', 'Delivered', 30),
(8,  101, 3, '2025-02-15', 'Shipped',   90),
(9,  101, 1, '2025-03-01', 'Delivered', 20),
(10, 102, 2, '2025-03-10', 'Delivered', 60),
(11, 103, 4, '2025-03-20', 'Shipped',   40);

CREATE TABLE Sales.Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    ManagerID  INT NULL
);

INSERT INTO Sales.Employees VALUES
(1, 'Frank',   NULL),   -- top of the hierarchy
(2, 'Kevin',   1),
(3, 'Mary',    1),
(4, 'Michael', 2),
(5, 'Carol',   2),
(6, 'Dan',     3);
```

Totals per customer (used throughout): Jossef 130, Kevin 95, Mary 155, Mark 40, Anna has no orders.

---

# Non-Recursive CTE

Executed **once**, with no repetition.

## Standalone CTE

Defined and used on its own. It reads only from real tables.

```sql
WITH CTE_total_sales AS (
    SELECT
        CustomerID,
        SUM(Sales) AS total_sales
    FROM Sales.Orders
    GROUP BY CustomerID
)
SELECT *
FROM CTE_total_sales;
```

| CustomerID | total_sales |
| ---------- | ----------- |
| 1          | 130         |
| 2          | 95          |
| 3          | 155         |
| 4          | 40          |

## Nested CTE

A nested CTE **uses the result of another CTE**, so it can't run independently.

```sql
WITH CTE_total_sales AS (               -- standalone
    SELECT
        CustomerID,
        SUM(Sales) AS total_sales
    FROM Sales.Orders
    GROUP BY CustomerID
),
CTE_customer_rank AS (                  -- nested: depends on CTE_total_sales
    SELECT
        CustomerID,
        total_sales,
        RANK() OVER (ORDER BY total_sales DESC) AS customer_rank
    FROM CTE_total_sales
)
SELECT *
FROM CTE_customer_rank;
```

| CustomerID | total_sales | customer_rank |
| ---------- | ----------- | ------------- |
| 3          | 155         | 1             |
| 1          | 130         | 2             |
| 2          | 95          | 3             |
| 4          | 40          | 4             |

This is the main benefit of CTEs: you build the query **step by step**, and each step has a name. Here it also avoids the problem where you can't `GROUP BY` and rank in one level without repeating the aggregate.

---

## Full Example: Customer Report

**Goal:** one row per customer with their total sales, last order date, sales rank and sales segment.

```sql
-- step 1 (standalone): total sales per customer
WITH CTE_total_sales AS (
    SELECT
        CustomerID,
        SUM(Sales) AS total_sales
    FROM Sales.Orders
    GROUP BY CustomerID
),
-- step 2 (standalone): last order date per customer
CTE_last_order AS (
    SELECT
        CustomerID,
        MAX(OrderDate) AS last_order
    FROM Sales.Orders
    GROUP BY CustomerID
),
-- step 3 (nested): rank customers by total sales
CTE_customer_rank AS (
    SELECT
        CustomerID,
        total_sales,
        RANK() OVER (ORDER BY total_sales DESC) AS customer_rank
    FROM CTE_total_sales
),
-- step 4 (nested): segment customers by total sales
CTE_customer_segment AS (
    SELECT
        CustomerID,
        CASE
            WHEN total_sales > 100 THEN 'High'
            WHEN total_sales > 80  THEN 'Medium'
            ELSE 'Low'
        END AS customer_segments
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
LEFT JOIN CTE_total_sales      AS cts ON cts.CustomerID = c.CustomerID
LEFT JOIN CTE_last_order       AS clo ON clo.CustomerID = c.CustomerID
LEFT JOIN CTE_customer_rank    AS ctr ON ctr.CustomerID = c.CustomerID
LEFT JOIN CTE_customer_segment AS ccs ON ccs.CustomerID = c.CustomerID;
```

| CustomerID | FirstName | LastName | total_sales | last_order | customer_rank | customer_segments |
| ---------- | --------- | -------- | ----------- | ---------- | ------------- | ----------------- |
| 1          | Jossef    | Goldberg | 130         | 2025-03-01 | 2             | High              |
| 2          | Kevin     | Brown    | 95          | 2025-03-10 | 3             | Medium            |
| 3          | Mary      | Dury     | 155         | 2025-02-15 | 1             | High              |
| 4          | Mark      | Schwarz  | 40          | 2025-03-20 | 4             | Low               |
| 5          | Anna      | Adams    | NULL        | NULL       | NULL          | NULL              |

**How it's built:**

| CTE                      | Type       | Reads from          |
| ------------------------ | ---------- | ------------------- |
| `CTE_total_sales`      | Standalone | `Sales.Orders`    |
| `CTE_last_order`       | Standalone | `Sales.Orders`    |
| `CTE_customer_rank`    | Nested     | `CTE_total_sales` |
| `CTE_customer_segment` | Nested     | `CTE_total_sales` |

**Notes:**

- **`LEFT JOIN` from `Sales.Customers`** keeps every customer. Anna has no orders, so she appears with `NULL`s. Use `COALESCE` for friendlier output, for example `COALESCE(cts.total_sales, 0)` and `COALESCE(ccs.customer_segments, 'No orders')`.
- **`CTE_total_sales` is used twice** (by the rank and by the segment CTE). That's the "use it multiple times" benefit. Remember it may be evaluated twice.
- **Segment thresholds:** `> 100` is High, `> 80` is Medium (so 80 itself is Low). `CASE` takes the first match, so the order of the `WHEN`s matters.
- **`CTE_total_sales` and `CTE_last_order` group the same table the same way**, so Orders is scanned twice. You can merge them into one CTE for efficiency:

```sql
WITH CTE_customer_stats AS (
    SELECT
        CustomerID,
        SUM(Sales)     AS total_sales,
        MAX(OrderDate) AS last_order
    FROM Sales.Orders
    GROUP BY CustomerID
)
SELECT ...
```

Splitting is fine for clarity. Merge when performance matters.

---

# Recursive CTE

A **self-referencing** query that repeatedly processes data until a condition is met. Typical uses: hierarchies (org charts, categories, folders), generating number or date series, and traversing graphs.

## Structure

```sql
WITH cte_name AS (
    -- 1. anchor member: the starting rows (runs once)
    SELECT ...

    UNION ALL

    -- 2. recursive member: refers to cte_name, runs repeatedly
    SELECT ...
    FROM cte_name
    WHERE <stop condition>
)
SELECT * FROM cte_name;
```

**How it runs:**

1. The **anchor** runs once and produces the first set of rows.
2. The **recursive member** runs against the rows produced in the previous step and produces the next set.
3. Step 2 repeats until the recursive member returns **no rows**, which is the stop condition.
4. All the sets are combined with `UNION ALL` and returned.

If the stop condition is missing or never becomes false, the recursion would run forever. SQL Server's recursion limit stops it with an error (see below).

## Example: Generate a Number Series

```sql
-- numbers 1 to 20
WITH Series AS (
    SELECT 1 AS my_number                -- anchor: start at 1
    UNION ALL
    SELECT my_number + 1                 -- recursive: add 1
    FROM Series
    WHERE my_number < 20                 -- stop condition
)
SELECT * FROM Series;
```

| my_number |
| --------- |
| 1         |
| 2         |
| 3         |
| ...       |
| 20        |

| Iteration | Input | Output                                  |
| --------- | ----- | --------------------------------------- |
| Anchor    |       | 1                                       |
| 1         | 1     | 2                                       |
| 2         | 2     | 3                                       |
| ...       | ...   | ...                                     |
| 19        | 19    | 20                                      |
| 20        | 20    | nothing (20 < 20 is false), so it stops |

## Example: Employee Hierarchy

Show every employee and their level in the org chart, where `ManagerID` points to another employee.

```sql
WITH CTE_Emp_Hierarchy AS (
    -- anchor: the top of the hierarchy (no manager)
    SELECT
        EmployeeID,
        FirstName,
        ManagerID,
        1 AS Level
    FROM Sales.Employees
    WHERE ManagerID IS NULL

    UNION ALL

    -- recursive: employees whose manager is already in the result
    SELECT
        e.EmployeeID,
        e.FirstName,
        e.ManagerID,
        h.Level + 1
    FROM Sales.Employees AS e
    INNER JOIN CTE_Emp_Hierarchy AS h
        ON e.ManagerID = h.EmployeeID
)
SELECT * FROM CTE_Emp_Hierarchy;
```

| EmployeeID | FirstName | ManagerID | Level |
| ---------- | --------- | --------- | ----- |
| 1          | Frank     | NULL      | 1     |
| 2          | Kevin     | 1         | 2     |
| 3          | Mary      | 1         | 2     |
| 4          | Michael   | 2         | 3     |
| 5          | Carol     | 2         | 3     |
| 6          | Dan       | 3         | 3     |

Each iteration finds the next level down: Frank first, then the people who report to Frank, then the people who report to them. It stops when nobody reports to the last set.

> If the data has a **cycle** (A manages B, B manages A), the recursion never ends and hits the limit. Add a depth cap (`WHERE h.Level < 10`) as a safety net.

## Example: Generate a Date Series

```sql
-- every day from 1 to 5 March 2025
WITH Dates AS (
    SELECT CAST('2025-03-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d)
    FROM Dates
    WHERE d < '2025-03-05'
)
SELECT * FROM Dates;
```

| d          |
| ---------- |
| 2025-03-01 |
| 2025-03-02 |
| 2025-03-03 |
| 2025-03-04 |
| 2025-03-05 |

A date series is handy for filling gaps: `LEFT JOIN` your orders onto it to get a row for every day, including days with no sales. It also fixes the "missing month" problem with `LAG`.

## Recursion Limit and MAXRECURSION

SQL Server stops a recursive CTE after **100 levels** by default:

```
The statement terminated. The maximum recursion 100 has been exhausted before statement completion.
```

Raise (or remove) the limit with a query hint at the **end of the main statement**:

```sql
WITH Series AS (
    SELECT 1 AS my_number
    UNION ALL
    SELECT my_number + 1 FROM Series WHERE my_number < 1000
)
SELECT * FROM Series
OPTION (MAXRECURSION 1000);      -- 0 = no limit (careful: infinite loops)
```

> A faster option for big number series is a numbers/tally table. Deep recursion is slow because each level is a separate step.

**Other rules for the recursive member:** it must reference the CTE exactly once, can't use `TOP`, `DISTINCT`, `GROUP BY`, aggregates or `OUTER JOIN` on the CTE reference, and the column types of the anchor and recursive parts must match.

---

# CTE vs Subquery vs Temp Table vs View

|                                   | CTE                                  | Subquery (derived table)         | Temp table (`#t`)                    | View                                     |
| --------------------------------- | ------------------------------------ | -------------------------------- | -------------------------------------- | ---------------------------------------- |
| **Lifetime**                | One statement                        | One statement                    | Session (until dropped)                | Permanent object                         |
| **Stored data?**            | No (re-evaluated)                    | No                               | **Yes** (materialised in tempdb) | No (just a saved query)                  |
| **Reuse in same statement** | Yes, by name                         | Must be repeated                 | Yes                                    | Yes                                      |
| **Reuse across statements** | No                                   | No                               | **Yes**                          | **Yes**                            |
| **Recursion**               | **Yes**                        | No                               | No                                     | No                                       |
| **Indexable**               | No                                   | No                               | **Yes**                          | Only if indexed view                     |
| **Best for**                | Readable multi-step logic, recursion | Quick one-offs,`IN`/`EXISTS` | Reusing an expensive result many times | Sharing a query between users or reports |

**Rules of thumb:**

- Several steps or readability? **CTE.**
- Quick single value or `WHERE x IN (...)`? **Subquery.**
- Expensive result used in many later statements? **Temp table.**
- Shared definition across queries? **View.**
- Hierarchy or series? **Recursive CTE.**

---

# CTEs With INSERT, UPDATE and DELETE

A CTE can sit in front of a data-changing statement, not just a `SELECT`.

**Insert the results of a CTE:**

```sql
WITH CTE_total_sales AS (
    SELECT CustomerID, SUM(Sales) AS total_sales
    FROM Sales.Orders
    GROUP BY CustomerID
)
INSERT INTO Sales.CustomerTotals (CustomerID, total_sales)
SELECT CustomerID, total_sales
FROM CTE_total_sales;
```

**Delete duplicates** (SQL Server lets you delete through a CTE):

```sql
WITH ranked AS (
    SELECT ROW_NUMBER() OVER (PARTITION BY OrderID ORDER BY CreationTime DESC) AS rn
    FROM Sales.OrdersArchive
)
DELETE FROM ranked
WHERE rn > 1;
```

Test with a `SELECT` first, and run the `DELETE` inside a transaction.

---

## Common Gotchas

1. **Missing semicolon before `WITH`.** `Incorrect syntax near the keyword 'WITH'.` End the previous statement with `;`.
2. **`ORDER BY` inside a CTE.** Not allowed without `TOP`/`OFFSET`. Sort in the main query.
3. **Using the CTE in a second statement.** It's gone after the first one. Re-define it or use a temp table.
4. **Referencing a later CTE.** A CTE can only see CTEs defined **before** it.
5. **Unnamed or duplicate column names.** Alias every expression, and don't repeat names. `Column names in each ... must be unique.`
6. **"It's cached."** A CTE isn't a temp table. Referencing it several times re-runs its query each time.
7. **Recursion limit.** Over 100 levels needs `OPTION (MAXRECURSION n)`. A missing stop condition or a data cycle also hits the limit.
8. **`UNION` instead of `UNION ALL` in a recursive CTE.** SQL Server requires `UNION ALL`.
9. **`LEFT JOIN` direction.** Join the CTEs **onto** the table you want to keep every row of (customers), or customers without orders disappear.
10. **Filtering a window function.** CTEs are the usual way to do it: compute the rank in the CTE, filter in the main query.

---

## Cheat Sheet

| I want...                              | Use                                                                      |
| -------------------------------------- | ------------------------------------------------------------------------ |
| A named, reusable step in a query      | `WITH name AS (SELECT ...) SELECT ... FROM name`                       |
| Several steps                          | `WITH a AS (...), b AS (SELECT ... FROM a) SELECT ... FROM b`          |
| Filter on a rank / window result       | Compute it in a CTE, filter in the main query                            |
| Number series                          | Recursive CTE: anchor`SELECT 1`, recursive `n + 1 ... WHERE n < max` |
| Org chart / hierarchy                  | Recursive CTE: anchor = top rows, recursive = join child to CTE          |
| More than 100 recursion levels         | `OPTION (MAXRECURSION n)` (0 = unlimited)                              |
| Insert / delete using a CTE            | `WITH ... INSERT ...` / `WITH ... DELETE FROM cte WHERE ...`         |
| Reuse a heavy result across statements | Temp table (`#t`), not a CTE                                           |

| Type       | Reads from       | Runs                                   |
| ---------- | ---------------- | -------------------------------------- |
| Standalone | Real tables only | Once                                   |
| Nested     | Another CTE      | Once                                   |
| Recursive  | Itself           | Repeatedly, until no rows are returned |
