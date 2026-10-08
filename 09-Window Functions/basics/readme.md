
# SQL Window Functions

A quick reference for window functions in **T-SQL (SQL Server)**: what they are, how they differ from `GROUP BY`, the `OVER` clause (`PARTITION BY`, `ORDER BY`, frame), and the main function types.

**Core idea:** a window function calculates over a *set of related rows* (the "window") but returns **one result for every row**. Nothing is collapsed.

---

## Table of Contents

- [GROUP BY vs Window Functions](#group-by-vs-window-functions)
- [Sample Data](#sample-data)
- [Window Syntax](#window-syntax)
- [Window Function Types](#window-function-types)
- [Empty OVER: Whole Table as One Window](#empty-over-whole-table-as-one-window)
- [PARTITION BY: Splitting Into Windows](#partition-by-splitting-into-windows)
- [ORDER BY: Ranking Rows](#order-by-ranking-rows)
- [Window Functions Together With GROUP BY](#window-functions-together-with-group-by)
- [Frame Clause](#frame-clause)
- [One Row Per Partition](#one-row-per-partition)
- [Rules](#rules)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## GROUP BY vs Window Functions

|                      | `GROUP BY`                                      | Window function                                                                      |
| -------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Rows returned        | **One row per group** (rows are collapsed)  | **Every row is kept**                                                          |
| Columns in`SELECT` | Only grouped columns and aggregates               | Any columns, plus the window result                                                  |
| Function types       | Aggregate only (`SUM`, `AVG`, `COUNT`, ...) | Aggregate, rank and value functions                                                  |
| Best for             | Simple data analysis                              | Advanced analysis (rankings, running totals, comparisons to a total or previous row) |

`GROUP BY` is enough for simple summaries. It breaks down when you want **detail rows and an aggregate side by side**, as shown next.

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
```

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

> Without an `ORDER BY` at the end of a query, SQL Server doesn't guarantee row order. Result tables below are shown in `OrderID` order for readability.

### The problem `GROUP BY` can't solve

```sql
-- total sales across all orders
SELECT SUM(Sales) AS total_sales
FROM Sales.Orders;
```

| total_sales |
| ----------- |
| 380         |

```sql
-- total sales for each product
SELECT
    ProductID,
    SUM(Sales) AS total_sales
FROM Sales.Orders
GROUP BY ProductID;
```

| ProductID | total_sales |
| --------- | ----------- |
| 101       | 140         |
| 102       | 105         |
| 104       | 75          |
| 105       | 60          |

Now add **order details** (order ID and date) next to the product total:

```sql
SELECT
    OrderID,
    OrderDate,
    ProductID,
    SUM(Sales) AS total_sales
FROM Sales.Orders
GROUP BY
    OrderID,
    OrderDate,
    ProductID;
```

| OrderID | OrderDate  | ProductID | total_sales |
| ------- | ---------- | --------- | ----------- |
| 1       | 2025-01-01 | 101       | 10          |
| 2       | 2025-01-05 | 102       | 15          |
| 3       | 2025-01-10 | 101       | 20          |
| ...     | ...        | ...       | ...         |

`GROUP BY` forces you to group by every column you select. Grouping by `OrderID` makes **each order its own group**, so `total_sales` is just that order's sales, not the product total. Product 101 shows 10, 20, 90 and 20 instead of 140.

This is where a window function is the right tool.

---

## Window Syntax

```sql
AVG(Sales) OVER (
    PARTITION BY Category
    ORDER BY OrderDate
    ROWS UNBOUNDED PRECEDING
)
```

| Part                         | Role                                                                        |
| ---------------------------- | --------------------------------------------------------------------------- |
| `AVG`                      | The**window function**: the calculation applied to the window         |
| `(Sales)`                  | The**function expression**: the column or value the function works on |
| `OVER (...)`               | The**OVER clause**: defines the window                                |
| `PARTITION BY`             | **Partition clause**: divides the dataset into windows (partitions)   |
| `ORDER BY`                 | **Order clause**: sorts the rows inside each window                   |
| `ROWS UNBOUNDED PRECEDING` | **Frame clause**: defines a subset of rows within the window          |

Everything inside `OVER (...)` is optional except where a function requires it (see [Rules](#rules)). An empty `OVER ()` means "the whole result set is one window".

---

## Window Function Types

| Category                    | Functions                                                                   | What they do                                                        |
| --------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **Aggregate**         | `COUNT(expr)`, `SUM(expr)`, `AVG(expr)`, `MAX(expr)`, `MIN(expr)` | Totals, averages, counts and extremes across the window             |
| **Rank**              | `ROW_NUMBER()`                                                            | Unique sequential number per row, no ties                           |
|                             | `RANK()`                                                                  | Rank with ties;**leaves gaps** after ties (1, 2, 2, 4)        |
|                             | `DENSE_RANK()`                                                            | Rank with ties;**no gaps** (1, 2, 2, 3)                       |
|                             | `CUME_DIST()`                                                             | Cumulative distribution: share of rows at or before the current row |
|                             | `PERCENT_RANK()`                                                          | Relative rank as a fraction between 0 and 1                         |
|                             | `NTILE(n)`                                                                | Splits the rows into`n` roughly equal buckets                     |
| **Value (analytics)** | `LEAD(expr, offset, default)`                                             | Value from a**following** row                                 |
|                             | `LAG(expr, offset, default)`                                              | Value from a**preceding** row                                 |
|                             | `FIRST_VALUE(expr)`                                                       | First value in the window                                           |
|                             | `LAST_VALUE(expr)`                                                        | Last value in the window                                            |

For `LEAD` / `LAG`, `offset` is how many rows to look away (default 1) and `default` is returned when there's no such row (otherwise `NULL`).

---

## Empty OVER: Whole Table as One Window

```sql
-- total sales across all orders, plus order details
SELECT
    OrderID,
    OrderDate,
    SUM(Sales) OVER () AS total_sales
FROM Sales.Orders;
```

| OrderID | OrderDate  | total_sales |
| ------- | ---------- | ----------- |
| 1       | 2025-01-01 | 380         |
| 2       | 2025-01-05 | 380         |
| 3       | 2025-01-10 | 380         |
| ...     | ...        | 380         |
| 10      | 2025-03-10 | 380         |

Every row gets the same total because the window is the entire table. Window functions return **a result for each row**.

---

## PARTITION BY: Splitting Into Windows

`PARTITION BY` divides the rows into separate windows. The function is calculated **inside each partition** and restarts for the next one.

```sql
-- total sales for each product, plus order details
SELECT
    OrderID,
    OrderDate,
    ProductID,
    SUM(Sales) OVER (PARTITION BY ProductID) AS total_sales
FROM Sales.Orders;
```

| OrderID | OrderDate  | ProductID | total_sales |
| ------- | ---------- | --------- | ----------- |
| 1       | 2025-01-01 | 101       | 140         |
| 2       | 2025-01-05 | 102       | 105         |
| 3       | 2025-01-10 | 101       | 140         |
| 4       | 2025-01-20 | 105       | 60          |
| 5       | 2025-02-01 | 104       | 75          |
| 6       | 2025-02-05 | 104       | 75          |
| 7       | 2025-02-10 | 102       | 105         |
| 8       | 2025-02-15 | 101       | 140         |
| 9       | 2025-03-01 | 101       | 140         |
| 10      | 2025-03-10 | 102       | 105         |

Every order keeps its own row, and each carries its product's total. This is what `GROUP BY` couldn't do.

### Several windows in one query

Each `OVER` is independent, so you can mix them freely:

```sql
-- total across all orders
-- total for each product
-- total for each product and order status combination
SELECT
    OrderID,
    OrderDate,
    ProductID,
    OrderStatus,
    Sales,
    SUM(Sales) OVER ()                                    AS total_sales,
    SUM(Sales) OVER (PARTITION BY ProductID)              AS total_sales_by_product,
    SUM(Sales) OVER (PARTITION BY ProductID, OrderStatus) AS sales_by_product_and_status
FROM Sales.Orders;
```

| OrderID | ProductID | OrderStatus | Sales | total_sales | total_sales_by_product | sales_by_product_and_status |
| ------- | --------- | ----------- | ----- | ----------- | ---------------------- | --------------------------- |
| 1       | 101       | Delivered   | 10    | 380         | 140                    | 50                          |
| 2       | 102       | Shipped     | 15    | 380         | 105                    | 15                          |
| 3       | 101       | Delivered   | 20    | 380         | 140                    | 50                          |
| 4       | 105       | Shipped     | 60    | 380         | 60                     | 60                          |
| 5       | 104       | Delivered   | 25    | 380         | 75                     | 25                          |
| 6       | 104       | Shipped     | 50    | 380         | 75                     | 50                          |
| 7       | 102       | Delivered   | 30    | 380         | 105                    | 90                          |
| 8       | 101       | Shipped     | 90    | 380         | 140                    | 90                          |
| 9       | 101       | Delivered   | 20    | 380         | 140                    | 50                          |
| 10      | 102       | Delivered   | 60    | 380         | 105                    | 90                          |

- `OVER ()`: one window, the whole table (380).
- `PARTITION BY ProductID`: one window per product.
- `PARTITION BY ProductID, OrderStatus`: one window per **combination**. Product 101 Delivered (orders 1, 3, 9) is 10 + 20 + 20 = 50, and 101 Shipped (order 8) is 90.

Having the detail row next to totals at several levels is what makes things like "each order as a percentage of its product total" easy:

```sql
Sales * 100.0 / SUM(Sales) OVER (PARTITION BY ProductID) AS pct_of_product
```

---

## ORDER BY: Ranking Rows

Inside `OVER`, `ORDER BY` sorts the rows within the window. Rank functions need it, because ranking requires an order.

```sql
-- rank each order by sales, highest to lowest
SELECT
    OrderID,
    OrderDate,
    Sales,
    RANK() OVER (ORDER BY Sales DESC) AS rank_sales
FROM Sales.Orders;
```

| OrderID | OrderDate  | Sales | rank_sales |
| ------- | ---------- | ----- | ---------- |
| 8       | 2025-02-15 | 90    | 1          |
| 4       | 2025-01-20 | 60    | 2          |
| 10      | 2025-03-10 | 60    | 2          |
| 6       | 2025-02-05 | 50    | 4          |
| 7       | 2025-02-10 | 30    | 5          |
| 5       | 2025-02-01 | 25    | 6          |
| 3       | 2025-01-10 | 20    | 7          |
| 9       | 2025-03-01 | 20    | 7          |
| 2       | 2025-01-05 | 15    | 9          |
| 1       | 2025-01-01 | 10    | 10         |

The two 60s tie at rank 2, and the next rank jumps to 4. With `DENSE_RANK()` the next rank would be 3, and with `ROW_NUMBER()` every row would get a unique number (the order between tied rows isn't guaranteed).

`ORDER BY` inside `OVER` only controls the window calculation. To control how the result is displayed, add a normal `ORDER BY` at the end of the query.

---

## Window Functions Together With GROUP BY

Window functions run **after** `GROUP BY`, so you can use an aggregate inside the `OVER` clause to rank grouped results.

```sql
-- rank customers by their total sales
SELECT
    CustomerID,
    SUM(Sales) AS total_sales,
    RANK() OVER (ORDER BY SUM(Sales) DESC) AS rank_customers
FROM Sales.Orders
GROUP BY CustomerID;
```

| CustomerID | total_sales | rank_customers |
| ---------- | ----------- | -------------- |
| 3          | 155         | 1              |
| 1          | 130         | 2              |
| 2          | 95          | 3              |

Step by step: `GROUP BY` first produces one row per customer with `SUM(Sales)`, then `RANK()` ranks those grouped rows.

> The reverse doesn't work: you can't put a window function inside `GROUP BY` or `WHERE`.

---

## Frame Clause

The frame clause narrows the window to **a subset of rows** around the current row. It's what turns a plain aggregate into a running total or a moving average.

### Syntax

```sql
AVG(Sales) OVER (
    PARTITION BY Category
    ORDER BY OrderDate
    ROWS BETWEEN <lower boundary> AND <higher boundary>
)
```

| Part                      | Options                                                   |
| ------------------------- | --------------------------------------------------------- |
| **Frame type**      | `ROWS`, `RANGE`                                       |
| **Lower boundary**  | `CURRENT ROW`, `N PRECEDING`, `UNBOUNDED PRECEDING` |
| **Higher boundary** | `CURRENT ROW`, `N FOLLOWING`, `UNBOUNDED FOLLOWING` |

- `UNBOUNDED PRECEDING`: from the first row of the partition.
- `N PRECEDING`: N rows before the current row.
- `CURRENT ROW`: the current row.
- `N FOLLOWING`: N rows after the current row.
- `UNBOUNDED FOLLOWING`: to the last row of the partition.

### Rules

1. The frame clause can only be used **together with `ORDER BY`**.
2. The **lower value must come before the higher value**.

> ⚠️ Rule 2 means `ROWS BETWEEN CURRENT ROW AND UNBOUNDED PRECEDING` (the example shown on the frame syntax slide) is **invalid**, since it puts the later boundary first. The valid forms are:
>
> ```sql
> ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW   -- start of partition to current row
> ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING   -- current row to end of partition
> ```
>
> The shorthand `ROWS UNBOUNDED PRECEDING` (no `BETWEEN`) means "from the start of the partition up to the current row". It's the same as the first form.

### Worked example: current row and 2 following

```sql
SUM(Sales) OVER (
    ORDER BY Month
    ROWS BETWEEN CURRENT ROW AND 2 FOLLOWING
)
```

| Month | Sales | Rows in the frame | Calculation  | Result |
| ----- | ----- | ----------------- | ------------ | ------ |
| Jan   | 20    | Jan, Feb, Mar     | 20 + 10 + 30 | 60     |
| Feb   | 10    | Feb, Mar, Apr     | 10 + 30 + 5  | 45     |
| Mar   | 30    | Mar, Apr, Jun     | 30 + 5 + 70  | 105    |
| Apr   | 5     | Apr, Jun          | 5 + 70       | 75     |
| Jun   | 70    | Jun               | 70           | 70     |

The frame slides down the rows. Near the end there aren't two following rows left, so the frame just uses what's there (Apr has one following row, Jun has none).

> The slide shows `70` for Jan, but 20 + 10 + 30 is **60**. The other four results match.

### Running total with `UNBOUNDED PRECEDING`

```sql
SELECT
    OrderID,
    OrderDate,
    Sales,
    SUM(Sales) OVER (
        ORDER BY OrderDate
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM Sales.Orders;
```

| OrderID | OrderDate  | Sales | running_total |
| ------- | ---------- | ----- | ------------- |
| 1       | 2025-01-01 | 10    | 10            |
| 2       | 2025-01-05 | 15    | 25            |
| 3       | 2025-01-10 | 20    | 45            |
| 4       | 2025-01-20 | 60    | 105           |
| 5       | 2025-02-01 | 25    | 130           |
| 6       | 2025-02-05 | 50    | 180           |
| 7       | 2025-02-10 | 30    | 210           |
| 8       | 2025-02-15 | 90    | 300           |
| 9       | 2025-03-01 | 20    | 320           |
| 10      | 2025-03-10 | 60    | 380           |

### Moving average

```sql
AVG(Sales) OVER (
    ORDER BY OrderDate
    ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING     -- previous, current and next row
)
```

### ROWS vs RANGE

- `ROWS` counts **physical rows**.
- `RANGE` treats rows with the **same `ORDER BY` value as one group** (peers), so they all get the same result.
- In SQL Server, `RANGE` only supports `UNBOUNDED` and `CURRENT ROW` boundaries. For `N PRECEDING` / `N FOLLOWING` use `ROWS`.

### What if you don't write a frame?

| `OVER` contains | Default frame                                         |
| ----------------- | ----------------------------------------------------- |
| No`ORDER BY`    | The**whole partition**                          |
| `ORDER BY`      | `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` |

---

## One Row Per Partition

A window function keeps every row. To get only one row per product, either use `GROUP BY` (if you only need the total), `SELECT DISTINCT` (if every selected column is identical within the partition), or keep one row per partition with `ROW_NUMBER()`:

```sql
SELECT *
FROM (
    SELECT
        ProductID,
        OrderID,
        OrderDate,
        SUM(Sales) OVER (PARTITION BY ProductID) AS total_sales_by_product,
        ROW_NUMBER() OVER (PARTITION BY ProductID ORDER BY OrderDate DESC) AS rn
    FROM Sales.Orders
) AS t
WHERE rn = 1;   -- latest order for each product, with the product total
```

You need the subquery (or a CTE) because a window function can't be used directly in `WHERE`.

---

## Rules

1. Window functions are allowed **only in `SELECT` and `ORDER BY`**, not in `WHERE`, `GROUP BY` or `HAVING`. To filter on the result, wrap the query in a subquery or CTE.
2. You **can't nest** a window function inside another window function.
3. **Rank functions** (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`, ...) and `LEAD` / `LAG` **require `ORDER BY`** in the `OVER` clause. Aggregate window functions don't.
4. The **frame clause requires `ORDER BY`**, and the lower boundary must come before the higher.
5. Window functions run **after** `WHERE`, `GROUP BY` and `HAVING`, so they only see the rows that survived those steps.
6. `PARTITION BY` can use several columns (`PARTITION BY ProductID, OrderStatus`).

---

## Common Gotchas

**1. Window functions don't reduce rows.** If you expected one row per group, you want `GROUP BY` or a `ROW_NUMBER() = 1` filter.

**2. Ties in `RANK()` leave gaps.** Use `DENSE_RANK()` for no gaps, `ROW_NUMBER()` for unique numbers. With `ROW_NUMBER()`, add a tiebreaker column to `ORDER BY` so the numbering is repeatable.

**3. `ORDER BY` inside `OVER` isn't the output order.** Add a final `ORDER BY` if you need sorted results.

**4. The default frame uses `RANGE`.** A running total built with just `ORDER BY` gives tied rows the same value. Write `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` for a strict running total.

**5. `LAST_VALUE` often looks "wrong".** With the default frame it only sees up to the current row, so it returns the current row's value. Extend the frame:

```sql
LAST_VALUE(Sales) OVER (
    ORDER BY OrderDate
    ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
)
```

**6. Aggregates ignore `NULL`s.** `AVG(Score) OVER ()` divides by the number of non-null values. Use `COALESCE(Score, 0)` if `NULL` should count as 0.

**7. Mixing window functions and `GROUP BY`:** the window function sees the **grouped** rows, so use aggregates inside it (`SUM(SUM(Sales)) OVER ()`, `RANK() OVER (ORDER BY SUM(Sales))`).

**8. Window functions can't be filtered in the same `WHERE`.** Use a subquery or CTE.

---

## Cheat Sheet

```sql
function(expression) OVER (
    [PARTITION BY col1, col2, ...]      -- split into windows
    [ORDER BY col [ASC | DESC]]         -- sort inside each window
    [ROWS | RANGE BETWEEN lower AND higher]   -- frame (needs ORDER BY)
)
```

| I want...                           | Use                                                                               |
| ----------------------------------- | --------------------------------------------------------------------------------- |
| A grand total next to every row     | `SUM(Sales) OVER ()`                                                            |
| A total per group next to every row | `SUM(Sales) OVER (PARTITION BY ProductID)`                                      |
| A rank                              | `RANK() OVER (ORDER BY Sales DESC)`                                             |
| Unique row numbers                  | `ROW_NUMBER() OVER (ORDER BY ...)`                                              |
| A running total                     | `SUM(Sales) OVER (ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` |
| A moving average                    | `AVG(Sales) OVER (ORDER BY d ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)`         |
| The previous / next row's value     | `LAG(Sales) OVER (ORDER BY d)` / `LEAD(Sales) OVER (ORDER BY d)`              |
| Rows split into n buckets           | `NTILE(4) OVER (ORDER BY Sales)`                                                |
| One row per group                   | `GROUP BY`, or `ROW_NUMBER() = 1` in a subquery                               |

| Function family                                                                             | Needs`ORDER BY` in `OVER`?                       |
| ------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Aggregate (`SUM`, `AVG`, `COUNT`, `MIN`, `MAX`)                                   | No (but required for a running calculation or frame) |
| Rank (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`, `CUME_DIST`, `PERCENT_RANK`) | Yes                                                  |
| Value (`LEAD`, `LAG`)                                                                   | Yes                                                  |
| Value (`FIRST_VALUE`, `LAST_VALUE`)                                                     | Yes                                                  |
