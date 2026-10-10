
# SQL Window Aggregate Functions

A quick reference for using `COUNT`, `SUM`, `AVG`, `MIN` and `MAX` as **window functions** in T-SQL (SQL Server): data quality checks, part-to-whole analysis, comparisons, running totals and rolling averages.

Unlike `GROUP BY`, a window aggregate keeps **every row** and adds the aggregate result next to it. See the [window functions README](sql-window-functions.md) for the `OVER` syntax basics.

---

## Table of Contents

- [Important Notes](#important-notes)
- [Sample Data](#sample-data)
- [COUNT](#count)
- [SUM](#sum)
- [AVG](#avg)
- [MIN / MAX](#min--max)
- [Running and Rolling Calculations](#running-and-rolling-calculations)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Important Notes

1. **Window aggregates don't collapse rows.** Every input row stays in the output, with the aggregate repeated on it. That's what lets you put details and totals side by side.
2. **`OVER ()` vs `OVER (PARTITION BY ...)`.** Empty `OVER ()` = the whole result is one window. `PARTITION BY` = one window per group, calculated separately.
3. **You can't filter on a window function in `WHERE`.** Wrap the query in a subquery or CTE, then filter the alias (used for duplicates, above-average orders and top salaries below).
4. **Adding `ORDER BY` inside `OVER` changes the meaning.** The aggregate becomes a **running** calculation (start of partition up to the current row) instead of one value for the whole partition.
5. **`ROWS BETWEEN ...` makes a fixed-size rolling window.** Without it, `ORDER BY` uses the default frame `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
6. **`COUNT(*)` counts rows, `COUNT(column)` skips `NULL`s.** `SUM`, `AVG`, `MIN` and `MAX` also ignore `NULL`s.
7. **`AVG` on an integer column returns an integer in SQL Server**, so the decimals are silently dropped (37.5 becomes 37). Use `AVG(Sales * 1.0)` or `AVG(CAST(Sales AS FLOAT))`.
8. **Integer division gotcha:** `Sales / SUM(Sales) OVER ()` on integers is 0 for most rows. `CAST` to `FLOAT` or `DECIMAL` first.

---

## Sample Data

```sql
CREATE SCHEMA Sales;
GO

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
(10, 102, 2, '2025-03-10', 'Delivered', 60);

-- no primary key, so duplicates are possible
CREATE TABLE Sales.OrdersArchive (
    OrderID   INT,
    ProductID INT,
    OrderDate DATE,
    Sales     INT
);

INSERT INTO Sales.OrdersArchive VALUES
(1, 101, '2024-01-05', 10),
(2, 102, '2024-01-20', 15),
(3, 101, '2024-02-02', 20),
(4, 105, '2024-02-10', 60),
(4, 105, '2024-02-10', 60),   -- duplicate OrderID
(5, 104, '2024-03-01', 25),
(6, 104, '2024-03-15', 50),
(6, 104, '2024-03-16', 55);   -- duplicate OrderID

CREATE TABLE Sales.Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    Salary     INT
);

INSERT INTO Sales.Employees VALUES
(1, 'Frank',   80000),
(2, 'Kevin',   55000),
(3, 'Mary',    75000),
(4, 'Michael', 90000),
(5, 'Carol',   90000);

CREATE TABLE Sales.Customers (
    CustomerID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    Score      INT
);

INSERT INTO Sales.Customers VALUES
(1, 'Jossef', 350),
(2, 'Kevin',  900),
(3, 'Mary',   750),
(4, 'Mark',   500),
(5, 'Anna',   NULL);
```

**Sales.Orders** (total sales = 380)

| OrderID | ProductID | CustomerID | OrderDate  | OrderStatus | Sales |
| ------- | --------- | ---------- | ---------- | ----------- | ----- |
| 1       | 101       | 2          | 2025-01-01 | Delivered   | 10    |
| 2       | 102       | 3          | 2025-01-05 | Shipped     | 15    |
| 3       | 101       | 1          | 2025-01-10 | Delivered   | 20    |
| 4       | 105       | 1          | 2025-01-20 | Shipped     | 60    |
| 5       | 104       | 2          | 2025-02-01 | Delivered   | 25    |
| 6       | 104       | 3          | 2025-02-05 | Shipped     | 50    |
| 7       | 102       | 1          | 2025-02-10 | Delivered   | 30    |
| 8       | 101       | 3          | 2025-02-15 | Shipped     | 90    |
| 9       | 101       | 1          | 2025-03-01 | Delivered   | 20    |
| 10      | 102       | 2          | 2025-03-10 | Delivered   | 60    |

> Without a final `ORDER BY`, SQL Server doesn't guarantee row order. Result tables below are shown in a readable order.

---

# COUNT

`COUNT()` returns the number of rows (or non-null values) in the window.

**Use cases:**

1. Overall analysis
2. Category analysis
3. Quality check: identify `NULL`s
4. Quality check: identify duplicates

### Quality check: identify duplicates

Duplicates lead to inaccurate analysis (inflated totals, double-counted customers), so check for them before trusting the data.

```sql
-- does the table contain duplicate primary keys?
SELECT
    OrderID,
    COUNT(*) OVER (PARTITION BY OrderID) AS check_primary_key
FROM Sales.OrdersArchive;
```

| OrderID | check_primary_key |
| ------- | ----------------- |
| 1       | 1                 |
| 2       | 1                 |
| 3       | 1                 |
| 4       | 2                 |
| 4       | 2                 |
| 5       | 1                 |
| 6       | 2                 |
| 6       | 2                 |

Any value above 1 means that `OrderID` appears more than once. To show only the problem rows, filter in an outer query (window functions can't go in `WHERE`):

```sql
SELECT *
FROM (
    SELECT
        OrderID,
        COUNT(*) OVER (PARTITION BY OrderID) AS check_primary_key
    FROM Sales.OrdersArchive
) AS t
WHERE check_primary_key > 1;
```

| OrderID | check_primary_key |
| ------- | ----------------- |
| 4       | 2                 |
| 4       | 2                 |
| 6       | 2                 |
| 6       | 2                 |

**Notes:**

- On `Sales.Orders` this returns all 1s, because `OrderID` is a primary key and can't repeat. Run the check on tables **without** a key constraint, like the archive.
- Order 4 is an **exact duplicate row**. Order 6 shares an ID but has different data (a different date and sales value), so it's a **conflict** that needs a human decision, not just a `DISTINCT`.
- To check for fully identical rows, partition by **all columns**: `COUNT(*) OVER (PARTITION BY OrderID, ProductID, OrderDate, Sales)`.
- If you only need the list of duplicated keys (not the rows), `GROUP BY OrderID HAVING COUNT(*) > 1` is simpler.

### Quality check: identify NULLs

`COUNT(*)` counts every row, `COUNT(column)` only counts rows where the column isn't `NULL`. The difference is the number of `NULL`s.

```sql
SELECT
    CustomerID,
    Score,
    COUNT(*)     OVER () AS total_rows,
    COUNT(Score) OVER () AS non_null_scores
FROM Sales.Customers;
```

| CustomerID | Score | total_rows | non_null_scores |
| ---------- | ----- | ---------- | --------------- |
| 1          | 350   | 5          | 4               |
| 2          | 900   | 5          | 4               |
| 3          | 750   | 5          | 4               |
| 4          | 500   | 5          | 4               |
| 5          | NULL  | 5          | 4               |

---

# SUM

`SUM()` returns the sum of values in the window. Ignores `NULL`s.

### Total across all orders and per product

```sql
-- total sales across all orders and total sales for each product,
-- plus order details
SELECT
    OrderID,
    OrderDate,
    Sales,
    ProductID,
    SUM(Sales) OVER ()                       AS total_sales_across_orders,
    SUM(Sales) OVER (PARTITION BY ProductID) AS sales_for_each_product
FROM Sales.Orders;
```

| OrderID | OrderDate  | Sales | ProductID | total_sales_across_orders | sales_for_each_product |
| ------- | ---------- | ----- | --------- | ------------------------- | ---------------------- |
| 1       | 2025-01-01 | 10    | 101       | 380                       | 140                    |
| 2       | 2025-01-05 | 15    | 102       | 380                       | 105                    |
| 3       | 2025-01-10 | 20    | 101       | 380                       | 140                    |
| 4       | 2025-01-20 | 60    | 105       | 380                       | 60                     |
| 5       | 2025-02-01 | 25    | 104       | 380                       | 75                     |
| 6       | 2025-02-05 | 50    | 104       | 380                       | 75                     |
| 7       | 2025-02-10 | 30    | 102       | 380                       | 105                    |
| 8       | 2025-02-15 | 90    | 101       | 380                       | 140                    |
| 9       | 2025-03-01 | 20    | 101       | 380                       | 140                    |
| 10      | 2025-03-10 | 60    | 102       | 380                       | 105                    |

### Use case: part-to-whole analysis

Comparing a single row to the total shows **how much it contributes**.

```sql
-- percentage contribution of each order's sales to the total sales
SELECT
    OrderID,
    ProductID,
    Sales,
    SUM(Sales) OVER () AS total_sales,
    ROUND(CAST(Sales AS FLOAT) / SUM(Sales) OVER () * 100, 2) AS percentage
FROM Sales.Orders;
```

| OrderID | ProductID | Sales | total_sales | percentage |
| ------- | --------- | ----- | ----------- | ---------- |
| 1       | 101       | 10    | 380         | 2.63       |
| 2       | 102       | 15    | 380         | 3.95       |
| 3       | 101       | 20    | 380         | 5.26       |
| 4       | 105       | 60    | 380         | 15.79      |
| 5       | 104       | 25    | 380         | 6.58       |
| 6       | 104       | 50    | 380         | 13.16      |
| 7       | 102       | 30    | 380         | 7.89       |
| 8       | 101       | 90    | 380         | 23.68      |
| 9       | 101       | 20    | 380         | 5.26       |
| 10      | 102       | 60    | 380         | 15.79      |

**Notes:**

- **Why `CAST(... AS FLOAT)`:** without it, `10 / 380` is integer division and gives `0`. Casting one side forces decimal division.
- This is each **order's** share of the total, not each **product's**. For a product's share, divide the product total by the grand total. Put both sums inside a `GROUP BY` query, or use `SUM(Sales) OVER (PARTITION BY ProductID) / SUM(Sales) OVER ()`:

```sql
SELECT DISTINCT
    ProductID,
    ROUND(CAST(SUM(Sales) OVER (PARTITION BY ProductID) AS FLOAT)
          / SUM(Sales) OVER () * 100, 2) AS product_share_pct
FROM Sales.Orders;
```

| ProductID | product_share_pct |
| --------- | ----------------- |
| 101       | 36.84             |
| 102       | 27.63             |
| 104       | 19.74             |
| 105       | 15.79             |

---

# AVG

`AVG()` returns the average of values in the window. Ignores `NULL`s (the divisor is the count of non-null values).

### Average across all orders and per product

```sql
SELECT
    OrderID,
    OrderDate,
    Sales,
    ProductID,
    AVG(Sales) OVER ()                       AS avg_sales,
    AVG(Sales) OVER (PARTITION BY ProductID) AS average_sales_by_product
FROM Sales.Orders;
```

| OrderID | OrderDate  | Sales | ProductID | avg_sales | average_sales_by_product |
| ------- | ---------- | ----- | --------- | --------- | ------------------------ |
| 1       | 2025-01-01 | 10    | 101       | 38        | 35                       |
| 2       | 2025-01-05 | 15    | 102       | 38        | 35                       |
| 3       | 2025-01-10 | 20    | 101       | 38        | 35                       |
| 4       | 2025-01-20 | 60    | 105       | 38        | 60                       |
| 5       | 2025-02-01 | 25    | 104       | 38        | **37**             |
| 6       | 2025-02-05 | 50    | 104       | 38        | **37**             |
| 7       | 2025-02-10 | 30    | 102       | 38        | 35                       |
| 8       | 2025-02-15 | 90    | 101       | 38        | 35                       |
| 9       | 2025-03-01 | 20    | 101       | 38        | 35                       |
| 10      | 2025-03-10 | 60    | 102       | 38        | 35                       |

> ⚠️ **Product 104's real average is 37.5**, but `Sales` is an `INT`, so SQL Server returns `37`. Use `AVG(Sales * 1.0)` or `AVG(CAST(Sales AS FLOAT))` to keep the decimals.

### Use case: compare each row to the average

**Task:** find all orders where sales are higher than the average across all orders.

You can't write `WHERE Sales > AVG(Sales) OVER ()`, so compute the average in a subquery first:

```sql
SELECT *
FROM (
    SELECT
        OrderID,
        OrderDate,
        Sales,
        AVG(Sales) OVER () AS avg_sales
    FROM Sales.Orders
) AS t
WHERE Sales > avg_sales;
```

| OrderID | OrderDate  | Sales | avg_sales |
| ------- | ---------- | ----- | --------- |
| 4       | 2025-01-20 | 60    | 38        |
| 6       | 2025-02-05 | 50    | 38        |
| 8       | 2025-02-15 | 90    | 38        |
| 10      | 2025-03-10 | 60    | 38        |

### Handling NULLs in averages

```sql
AVG(Score) OVER ()                  -- ignores NULLs: divides by non-null count
AVG(COALESCE(Score, 0)) OVER ()     -- treats NULL as 0: divides by all rows
```

Decide whether a missing value means "unknown, exclude it" or "zero".

---

# MIN / MAX

`MIN()` and `MAX()` return the smallest and largest value in the window.

### Highest and lowest sales

```sql
-- highest and lowest sales across all orders,
-- and for each product, plus order details
SELECT
    OrderID,
    OrderDate,
    ProductID,
    Sales,
    MAX(Sales) OVER ()                       AS highest_sales,
    MIN(Sales) OVER ()                       AS lowest_sales,
    MAX(Sales) OVER (PARTITION BY ProductID) AS highest_sales_by_product,
    MIN(Sales) OVER (PARTITION BY ProductID) AS lowest_sales_by_product
FROM Sales.Orders;
```

| OrderID | ProductID | Sales | highest_sales | lowest_sales | highest_by_product | lowest_by_product |
| ------- | --------- | ----- | ------------- | ------------ | ------------------ | ----------------- |
| 1       | 101       | 10    | 90            | 10           | 90                 | 10                |
| 2       | 102       | 15    | 90            | 10           | 60                 | 15                |
| 3       | 101       | 20    | 90            | 10           | 90                 | 10                |
| 4       | 105       | 60    | 90            | 10           | 60                 | 60                |
| 5       | 104       | 25    | 90            | 10           | 50                 | 25                |
| 6       | 104       | 50    | 90            | 10           | 50                 | 25                |
| 7       | 102       | 30    | 90            | 10           | 60                 | 15                |
| 8       | 101       | 90    | 90            | 10           | 90                 | 10                |
| 9       | 101       | 20    | 90            | 10           | 90                 | 10                |
| 10      | 102       | 60    | 90            | 10           | 60                 | 15                |

### Use case: find the rows with the highest value

**Task:** show the employees who have the highest salary.

```sql
SELECT *
FROM (
    SELECT
        *,
        MAX(Salary) OVER () AS highest_salary
    FROM Sales.Employees
) AS t
WHERE highest_salary = Salary;
```

| EmployeeID | FirstName | Salary | highest_salary |
| ---------- | --------- | ------ | -------------- |
| 4          | Michael   | 90000  | 90000          |
| 5          | Carol     | 90000  | 90000          |

**Notes:**

- **Ties are all returned**, which is usually what you want for "who has the highest salary". `TOP 1` or `ROW_NUMBER() = 1` would return only one of them.
- For a per-group version, add `PARTITION BY` (for example highest salary per department).

### Use case: deviation from the minimum and maximum

```sql
SELECT
    OrderID,
    OrderDate,
    ProductID,
    Sales,
    MAX(Sales) OVER ()         AS highest_sales,
    MIN(Sales) OVER ()         AS lowest_sales,
    Sales - MIN(Sales) OVER () AS deviation_from_min,
    MAX(Sales) OVER () - Sales AS deviation_from_max
FROM Sales.Orders;
```

| OrderID | Sales | highest_sales | lowest_sales | deviation_from_min | deviation_from_max |
| ------- | ----- | ------------- | ------------ | ------------------ | ------------------ |
| 1       | 10    | 90            | 10           | 0                  | 80                 |
| 2       | 15    | 90            | 10           | 5                  | 75                 |
| 3       | 20    | 90            | 10           | 10                 | 70                 |
| 4       | 60    | 90            | 10           | 50                 | 30                 |
| 5       | 25    | 90            | 10           | 15                 | 65                 |
| 6       | 50    | 90            | 10           | 40                 | 40                 |
| 7       | 30    | 90            | 10           | 20                 | 60                 |
| 8       | 90    | 90            | 10           | 80                 | 0                  |
| 9       | 20    | 90            | 10           | 10                 | 70                 |
| 10      | 60    | 90            | 10           | 50                 | 30                 |

The lowest sale has `deviation_from_min = 0`, and the highest has `deviation_from_max = 0`. You can also use this for min-max normalisation: `(Sales - MIN) / (MAX - MIN)` gives a 0 to 1 scale.

---

# Running and Rolling Calculations

Add `ORDER BY` (and optionally a frame) inside `OVER` to calculate over a **growing or sliding set of rows** instead of the whole partition.

| Type                           | Window                                        | Frame                                                                                               |
| ------------------------------ | --------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Running** (cumulative) | Start of partition up to the current row      | `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` (the default with `ORDER BY` uses `RANGE`) |
| **Rolling** (moving)     | A fixed number of rows around the current row | `ROWS BETWEEN n PRECEDING AND CURRENT ROW`, `CURRENT ROW AND n FOLLOWING`, etc.                 |

Running and rolling totals/averages are built with `SUM` and `AVG` (and `COUNT`, `MIN`, `MAX`). They aren't specific to `MIN`/`MAX`.

### Running average (`ORDER BY` only)

**Task:** calculate the average sales for each product over time.

```sql
SELECT
    OrderID,
    ProductID,
    OrderDate,
    Sales,
    AVG(Sales) OVER (PARTITION BY ProductID)                      AS avg_by_product,
    AVG(Sales) OVER (PARTITION BY ProductID ORDER BY OrderDate)   AS running_average
FROM Sales.Orders;
```

| OrderID | ProductID | OrderDate  | Sales | avg_by_product | running_average |
| ------- | --------- | ---------- | ----- | -------------- | --------------- |
| 1       | 101       | 2025-01-01 | 10    | 35             | 10              |
| 3       | 101       | 2025-01-10 | 20    | 35             | 15              |
| 8       | 101       | 2025-02-15 | 90    | 35             | 40              |
| 9       | 101       | 2025-03-01 | 20    | 35             | 35              |
| 2       | 102       | 2025-01-05 | 15    | 35             | 15              |
| 7       | 102       | 2025-02-10 | 30    | 35             | 22              |
| 10      | 102       | 2025-03-10 | 60    | 35             | 35              |
| 5       | 104       | 2025-02-01 | 25    | 37             | 25              |
| 6       | 104       | 2025-02-05 | 50    | 37             | 37              |
| 4       | 105       | 2025-01-20 | 60    | 60             | 60              |

How product 101's running average builds up:

| Row    | Rows included         | Calculation             | Result |
| ------ | --------------------- | ----------------------- | ------ |
| Jan 1  | Jan 1                 | 10                      | 10     |
| Jan 10 | Jan 1, Jan 10         | (10 + 20) / 2           | 15     |
| Feb 15 | Jan 1, Jan 10, Feb 15 | (10 + 20 + 90) / 3      | 40     |
| Mar 1  | all four              | (10 + 20 + 90 + 20) / 4 | 35     |

The last row of each partition equals the whole-partition average (35 for product 101).

> **This is a running (cumulative) average, not a moving average.** With only `ORDER BY`, the window always starts at the first row of the partition and grows. A true moving average uses a fixed-size frame (next section).
>
> Decimals are truncated here too (product 102 shows 22, but the real value is 22.5). Use `AVG(Sales * 1.0)` for decimals.

### Rolling average (fixed frame)

**Task:** calculate the rolling average of sales for each product over time, including only the next order.

```sql
SELECT
    OrderID,
    ProductID,
    OrderDate,
    Sales,
    AVG(Sales) OVER (
        PARTITION BY ProductID
        ORDER BY OrderDate
        ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING
    ) AS rolling_avg
FROM Sales.Orders;
```

| OrderID | ProductID | OrderDate  | Sales | rolling_avg |
| ------- | --------- | ---------- | ----- | ----------- |
| 1       | 101       | 2025-01-01 | 10    | 15          |
| 3       | 101       | 2025-01-10 | 20    | 55          |
| 8       | 101       | 2025-02-15 | 90    | 55          |
| 9       | 101       | 2025-03-01 | 20    | 20          |
| 2       | 102       | 2025-01-05 | 15    | 22          |
| 7       | 102       | 2025-02-10 | 30    | 45          |
| 10      | 102       | 2025-03-10 | 60    | 60          |
| 5       | 104       | 2025-02-01 | 25    | 37          |
| 6       | 104       | 2025-02-05 | 50    | 50          |
| 4       | 105       | 2025-01-20 | 60    | 60          |

How product 101 works (current row and the next one):

| Row    | Rows in the frame | Calculation   | Result |
| ------ | ----------------- | ------------- | ------ |
| Jan 1  | Jan 1, Jan 10     | (10 + 20) / 2 | 15     |
| Jan 10 | Jan 10, Feb 15    | (20 + 90) / 2 | 55     |
| Feb 15 | Feb 15, Mar 1     | (90 + 20) / 2 | 55     |
| Mar 1  | Mar 1 only        | 20            | 20     |

**Notes:**

- The **last row in each partition has no following row**, so its average is just itself (Mar 1 = 20). Products with a single order (105) just return their own value.
- `PARTITION BY ProductID` means the frame never crosses into another product.
- The frame counts **rows, not dates**, so "next order" can be weeks away. For a calendar-based window (for example the last 30 days) you need a different approach, such as a self-join or `APPLY`.
- Decimals are truncated again (product 102's first row is 22, real value 22.5).

### Running total (`SUM`)

```sql
SUM(Sales) OVER (
    PARTITION BY ProductID
    ORDER BY OrderDate
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS running_total
```

Specify `ROWS` explicitly. The default `RANGE` frame gives rows with the **same `ORDER BY` value** the same total, which is rarely what you want for a running total.

---

## Common Gotchas

1. **Filtering on a window result.** Not allowed in `WHERE`. Use a subquery or CTE.
2. **`AVG` of integers truncates.** 37.5 becomes 37. Multiply by `1.0` or cast.
3. **Integer division in percentages.** `Sales / SUM(Sales) OVER ()` is 0. Cast to `FLOAT` first.
4. **`COUNT(*)` vs `COUNT(column)`.** Only `COUNT(column)` skips `NULL`s.
5. **`NULL`s in `AVG`/`SUM`.** Ignored, which changes the divisor. Use `COALESCE` if you want them as 0.
6. **`ORDER BY` in `OVER` turns the aggregate into a running one.** If you wanted the overall average per product, leave `ORDER BY` out.
7. **A moving average needs a `ROWS` frame.** `ORDER BY` alone gives a cumulative average.
8. **Partition boundaries.** Rolling frames don't cross `PARTITION BY` boundaries. The first/last rows of each partition use fewer rows.
9. **Duplicate checks only work if you partition by the right columns.** Partitioning by the primary key finds repeated IDs, but not repeated records with different IDs.
10. **Ties in `MAX`/`MIN` filters return every tied row.** Use `ROW_NUMBER()` if you need exactly one.

---

## Cheat Sheet

| I want...                        | Use                                                                                  |
| -------------------------------- | ------------------------------------------------------------------------------------ |
| Find duplicate keys              | `COUNT(*) OVER (PARTITION BY key)` then filter `> 1` in an outer query           |
| Count`NULL`s                   | `COUNT(*) OVER () - COUNT(col) OVER ()`                                            |
| Grand total next to each row     | `SUM(Sales) OVER ()`                                                               |
| Total per group next to each row | `SUM(Sales) OVER (PARTITION BY ProductID)`                                         |
| Each row's % of the total        | `CAST(Sales AS FLOAT) / SUM(Sales) OVER () * 100`                                  |
| Average, with decimals           | `AVG(Sales * 1.0) OVER (...)`                                                      |
| Rows above average               | `AVG(Sales) OVER ()` in a subquery, then `WHERE Sales > avg`                     |
| Highest / lowest overall         | `MAX(Sales) OVER ()` / `MIN(Sales) OVER ()`                                      |
| Highest / lowest per group       | `MAX(Sales) OVER (PARTITION BY ProductID)`                                         |
| Rows with the highest value      | Subquery with`MAX(col) OVER ()`, then `WHERE col = max_col`                      |
| Deviation from min / max         | `Sales - MIN(Sales) OVER ()` / `MAX(Sales) OVER () - Sales`                      |
| Running total                    | `SUM(x) OVER (ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`        |
| Running average                  | `AVG(x) OVER (PARTITION BY g ORDER BY d)`                                          |
| Rolling average                  | `AVG(x) OVER (PARTITION BY g ORDER BY d ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` |
