
# SQL `CASE WHEN`

A quick reference for `CASE` expressions: conditional logic inside a query. Covers categorizing data, mapping values, handling `NULL`s, and conditional aggregation.

`CASE` evaluates a list of conditions **in order** and returns the result of the **first one that is true**. Its main purpose is **data transformation**: deriving new information and creating new columns from existing data.

> Examples use SQL Server (T-SQL). `CASE` itself is standard SQL and works in every major database.

---

## Table of Contents

- [Syntax](#syntax)
- [Sample Data](#sample-data)
- [Use Case: Categorizing Data](#use-case-categorizing-data)
- [Use Case: Mapping Values](#use-case-mapping-values)
- [Use Case: Handling NULLs](#use-case-handling-nulls)
- [Use Case: Conditional Aggregation](#use-case-conditional-aggregation)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Syntax

**Searched form:** each `WHEN` holds a full condition. Most flexible, so use this one by default.

```sql
CASE
    WHEN condition1 THEN result1
    WHEN condition2 THEN result2
    ELSE default_result
END
```

**Simple form:** compares one expression to a list of values (equality only).

```sql
CASE column
    WHEN value1 THEN result1
    WHEN value2 THEN result2
    ELSE default_result
END
```

Rules:

- Conditions are checked **top to bottom**; the first true one wins and the rest are skipped.
- If nothing matches and there's **no `ELSE`**, the result is `NULL`.
- All `THEN` / `ELSE` results must have **matching (compatible) data types**.

---

## Sample Data

```sql
CREATE SCHEMA Sales;
GO

CREATE TABLE Sales.Orders (
    OrderID    INT PRIMARY KEY,
    CustomerID INT,
    Sales      INT
);

INSERT INTO Sales.Orders VALUES
(1001, 1, 10),
(1002, 2, 15),
(1003, 3, 20),
(1004, 1, 25),
(1005, 2, 50),
(1006, 3, 55),
(1007, 1, 60),
(1008, 2, 35),
(1009, 4, 5);

CREATE TABLE Sales.Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    LastName   VARCHAR(50),
    Gender     CHAR(1)
);

INSERT INTO Sales.Employees VALUES
(1, 'Frank',   'Lee',   'M'),
(2, 'Kevin',   'Brown', 'M'),
(3, 'Mary',    'Dury',  'F'),
(4, 'Carol',   'Baker', 'F'),
(5, 'Michael', 'Ray',   NULL);

CREATE TABLE Sales.Customers (
    CustomerID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    LastName   VARCHAR(50),
    Country    VARCHAR(50),
    Score      INT
);

INSERT INTO Sales.Customers VALUES
(1, 'Jossef', 'Goldberg', 'Germany', 350),
(2, 'Kevin',  'Brown',    'USA',     900),
(3, 'Mary',   NULL,       'USA',     750),
(4, 'Mark',   'Schwarz',  'Germany', 500),
(5, 'Anna',   'Adams',    'USA',     NULL);
```

The order sales values deliberately include the boundaries (20 and 50) so you can see which branch they land in.

---

## Use Case: Categorizing Data

**Task:** generate a report showing the total sales for each category:

- **High:** sales higher than 50
- **Medium:** sales above 20, up to and including 50
- **Low:** sales of 20 or less

```sql
SELECT
    category,
    SUM(Sales) AS total_sales
FROM (
    SELECT
        OrderID,
        Sales,
        CASE
            WHEN Sales > 50 THEN 'High'
            WHEN Sales > 20 THEN 'Medium'
            ELSE 'Low'
        END AS category
    FROM Sales.Orders
) AS t
GROUP BY category
ORDER BY total_sales DESC;
```

**Inner query** (what each order gets labelled):

| OrderID | Sales | category |
| ------- | ----- | -------- |
| 1001    | 10    | Low      |
| 1002    | 15    | Low      |
| 1003    | 20    | Low      |
| 1004    | 25    | Medium   |
| 1005    | 50    | Medium   |
| 1006    | 55    | High     |
| 1007    | 60    | High     |
| 1008    | 35    | Medium   |
| 1009    | 5     | Low      |

**Final result:**

| category | total_sales |
| -------- | ----------- |
| High     | 115         |
| Medium   | 110         |
| Low      | 50          |

**How it works:**

- Conditions run top to bottom. Sales of 60 hits `> 50` first and stops, so the `Medium` branch doesn't need an upper bound (`> 20 AND <= 50`). That's why 50 is Medium and 20 is Low.
- **Why the subquery?** In SQL Server you can't use a `SELECT` alias (`category`) in `GROUP BY` of the same query. Wrapping the `CASE` in a subquery (or a CTE) lets you group by the alias. The alternative is repeating the whole `CASE` expression in `GROUP BY`.
- `ORDER BY` can use aliases, so `total_sales DESC` works.

---

## Use Case: Mapping Values

Transform values from one form to another, such as codes into readable text.

**Task:** retrieve employee details with gender displayed as full text.

```sql
SELECT
    EmployeeID,
    FirstName,
    LastName,
    Gender,
    CASE
        WHEN Gender = 'F' THEN 'Female'
        WHEN Gender = 'M' THEN 'Male'
        ELSE 'Not Available'
    END AS gender_full_text
FROM Sales.Employees;
```

| EmployeeID | FirstName | LastName | Gender | gender_full_text |
| ---------- | --------- | -------- | ------ | ---------------- |
| 1          | Frank     | Lee      | M      | Male             |
| 2          | Kevin     | Brown    | M      | Male             |
| 3          | Mary      | Dury     | F      | Female           |
| 4          | Carol     | Baker    | F      | Female           |
| 5          | Michael   | Ray      | NULL   | Not Available    |

The `ELSE` branch catches both `NULL`s and any unexpected codes.

**Same query using the simple form** (less typing when you're only testing equality):

```sql
CASE Gender
    WHEN 'F' THEN 'Female'
    WHEN 'M' THEN 'Male'
    ELSE 'Not Available'
END AS gender_full_text
```

> ⚠️ The simple form uses `=` internally, so `WHEN NULL THEN ...` **never matches**. To test for `NULL`, use the searched form with `WHEN Gender IS NULL`.

---

## Use Case: Handling NULLs

Replace `NULL`s with a specific value **before aggregating**.

**Task:** find the average score of customers, treating `NULL` as 0.

```sql
SELECT
    CustomerID,
    LastName,
    Score,
    AVG(CASE
            WHEN Score IS NULL THEN 0
            ELSE Score
        END) OVER () AS avg_score
FROM Sales.Customers;
```

| CustomerID | LastName | Score | avg_score |
| ---------- | -------- | ----- | --------- |
| 1          | Goldberg | 350   | 500       |
| 2          | Brown    | 900   | 500       |
| 3          | NULL     | 750   | 500       |
| 4          | Schwarz  | 500   | 500       |
| 5          | Adams    | NULL  | 500       |

With `NULL` counted as 0 it's (350 + 900 + 750 + 500 + 0) / **5** = 500. A plain `AVG(Score)` ignores the `NULL` and gives (2500) / **4** = 625.

> `COALESCE(Score, 0)` does the same job with less code: `AVG(COALESCE(Score, 0)) OVER ()`. Use `CASE` when you need more complex logic than a simple replacement.

---

## Use Case: Conditional Aggregation

Use `CASE` **inside an aggregate function** to count or sum only the rows that meet a condition.

**Task:** count how many orders each customer has made with sales greater than 30.

```sql
SELECT
    CustomerID,
    SUM(CASE WHEN Sales > 30 THEN 1 ELSE 0 END) AS high_value_orders
FROM Sales.Orders
GROUP BY CustomerID;
```

| CustomerID | high_value_orders |
| ---------- | ----------------- |
| 1          | 1                 |
| 2          | 2                 |
| 3          | 1                 |
| 4          | 0                 |

**How it works:** each order becomes `1` if it qualifies and `0` if not, and `SUM` adds them up.

- Customer 4 has one order (sales of 5), which doesn't qualify, so they get `0` instead of disappearing. If you used `WHERE Sales > 30` instead, customer 4 would be missing from the result entirely.
- The `ELSE 0` matters. Without it, non-matching rows become `NULL`, and a customer with no qualifying orders would get `NULL` from `SUM` instead of `0`.

**Equivalent with `COUNT`:** `COUNT` ignores `NULL`s, so you can skip the `ELSE` and the `1/0`:

```sql
COUNT(CASE WHEN Sales > 30 THEN 1 END) AS high_value_orders
```

Conditional aggregation is also how you build pivot-style reports (one column per category) in a single pass over the data.

---

## Common Gotchas

**1. Order matters.** The first true condition wins. Put the most specific or most restrictive condition first.

```sql
-- ❌ everything above 20 is 'Medium'; 'High' is never reached
CASE
    WHEN Sales > 20 THEN 'Medium'
    WHEN Sales > 50 THEN 'High'
    ELSE 'Low'
END
```

**2. No `ELSE` means `NULL`.** Add an `ELSE` unless you want unmatched rows to be `NULL`.

**3. Data types must match.** SQL Server picks the result type by data type precedence, and mixing text and numbers fails:

```sql
-- ❌ Conversion failed when converting the varchar value 'High' to data type int
CASE WHEN Sales > 50 THEN 'High' ELSE 0 END

-- ✅ keep every branch the same type
CASE WHEN Sales > 50 THEN 'High' ELSE 'None' END
```

**4. Check your boundaries.** `>` vs `>=` decides where the edge values go. Test with values exactly on the boundaries (20 and 50 in the sample data).

**5. Simple `CASE` can't match `NULL`.** Use `WHEN column IS NULL` in the searched form.

**6. Can't group by the alias in the same query** (SQL Server). Use a subquery or CTE, or repeat the expression in `GROUP BY`.

**7. It's an expression, not a statement.** `CASE` returns a value, so it can be used in `SELECT`, `WHERE`, `ORDER BY`, `GROUP BY`, and inside aggregate functions. It can't run different statements (that's `IF` in procedural code).

---

## Cheat Sheet

| Use case            | Pattern                                                                           |
| ------------------- | --------------------------------------------------------------------------------- |
| Categorize numbers  | `CASE WHEN x > 50 THEN 'High' WHEN x > 20 THEN 'Medium' ELSE 'Low' END`         |
| Map codes to text   | `CASE col WHEN 'F' THEN 'Female' WHEN 'M' THEN 'Male' ELSE 'N/A' END`           |
| Replace`NULL`     | `CASE WHEN col IS NULL THEN 0 ELSE col END` (or `COALESCE(col, 0)`)           |
| Count matching rows | `SUM(CASE WHEN cond THEN 1 ELSE 0 END)` or `COUNT(CASE WHEN cond THEN 1 END)` |
| Sum matching values | `SUM(CASE WHEN cond THEN amount ELSE 0 END)`                                    |
| Custom sort order   | `ORDER BY CASE WHEN col IS NULL THEN 1 ELSE 0 END, col`                         |

**Quick rules:**

- Most specific condition first.
- Always add an `ELSE`.
- Every branch returns the same data type.
- Two-way choice in SQL Server? `IIF(cond, a, b)` is shorthand for `CASE WHEN cond THEN a ELSE b END`.
