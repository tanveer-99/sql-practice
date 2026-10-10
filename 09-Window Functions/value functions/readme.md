
# SQL Value (Analytics) Window Functions

A quick reference for `LAG`, `LEAD`, `FIRST_VALUE` and `LAST_VALUE` in T-SQL (SQL Server). These functions **access a value from another row** in the same window, so you can compare a row with the previous row, the next row, or the first or last row of its group, without a self-join.

Like all window functions, they **keep every row**. See the [window functions README](sql-window-functions.md) for `OVER` basics.

---

## Table of Contents

- [Important Notes](#important-notes)
- [Overview](#overview)
- [Sample Data](#sample-data)
- [LAG and LEAD](#lag-and-lead)
  - [Syntax](#syntax) · [Basic example](#basic-example) · [Month-over-month analysis](#use-case-month-over-month-mom-analysis) · [Customer retention](#use-case-customer-retention-analysis)
- [FIRST_VALUE and LAST_VALUE](#first_value-and-last_value)
  - [FIRST_VALUE](#first_value) · [LAST_VALUE](#last_value-and-the-frame-trap) · [Use case: compare to first/last](#use-case-compare-each-row-to-the-lowest-and-highest)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Important Notes

1. **`ORDER BY` inside `OVER` is required** for all four functions. "Previous", "next", "first" and "last" mean nothing without an order.
2. **`LAG` looks back, `LEAD` looks forward.** The first row has no previous row, so `LAG` returns `NULL` there. The last row has no next row, so `LEAD` returns `NULL` there.
3. **Both take an optional offset and default value:** `LAG(expr, offset, default)`. The offset (default 1) is how many rows to jump. The default replaces the `NULL` returned when there's no such row.
4. **`PARTITION BY` restarts the lookup per group.** Without it, the first row of customer 2 would "see" the last row of customer 1.
5. **`LAG`/`LEAD` ignore frame clauses.** They always jump by row offset. **`FIRST_VALUE`/`LAST_VALUE` do depend on the frame**, which is the source of the biggest gotcha below.
6. **`LAST_VALUE` often looks "wrong" with the default frame.** The default frame stops at the current row, so `LAST_VALUE` just returns the current row's value. Extend the frame to `UNBOUNDED FOLLOWING`, or use `FIRST_VALUE` with the opposite sort order.
7. **Sort by real values, not names.** Ordering by `DATENAME(MONTH, ...)` sorts alphabetically, so `LAG` returns the wrong "previous month". Sort by `MONTH()` or a real date.
8. **`LAG`/`LEAD` count rows, not time.** If a month is missing from the data, "previous row" is not "previous month".
9. **A window function can wrap an aggregate** (`LAG(SUM(Sales)) OVER (...)`) because window functions run after `GROUP BY`. Everything else in `SELECT` must still be grouped or aggregated.

---

## Overview

| Function                        | Returns                                           |
| ------------------------------- | ------------------------------------------------- |
| `LAG(expr, offset, default)`  | Value from a**previous** row in the window  |
| `LEAD(expr, offset, default)` | Value from a**following** row in the window |
| `FIRST_VALUE(expr)`           | Value from the**first** row in the window   |
| `LAST_VALUE(expr)`            | Value from the**last** row in the window    |

**Typical uses:**

- **Time-series analysis:** month-over-month (MoM), year-over-year (YoY) change in a business
- **Customer retention:** how long between a customer's orders
- **Comparing to a benchmark:** how far each row is from the lowest or highest in its group

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
(10, 102, 2, '2025-03-10', 'Delivered', 60),
(11, 103, 4, '2025-03-20', 'Shipped',   40);   -- customer 4: a single order
```

| OrderID | ProductID | CustomerID | OrderDate  | Sales |
| ------- | --------- | ---------- | ---------- | ----- |
| 1       | 101       | 2          | 2025-01-01 | 10    |
| 2       | 102       | 3          | 2025-01-05 | 15    |
| 3       | 101       | 1          | 2025-01-10 | 20    |
| 4       | 105       | 1          | 2025-01-20 | 60    |
| 5       | 104       | 2          | 2025-02-01 | 25    |
| 6       | 104       | 3          | 2025-02-05 | 50    |
| 7       | 102       | 1          | 2025-02-10 | 30    |
| 8       | 101       | 3          | 2025-02-15 | 90    |
| 9       | 101       | 1          | 2025-03-01 | 20    |
| 10      | 102       | 2          | 2025-03-10 | 60    |
| 11      | 103       | 4          | 2025-03-20 | 40    |

> This README adds one order (11) compared with the other READMEs, so customer 4 shows how single-order customers behave.

---

# LAG and LEAD

## Syntax

```sql
LAG(expression, offset, default)  OVER ([PARTITION BY ...] ORDER BY ...)
LEAD(expression, offset, default) OVER ([PARTITION BY ...] ORDER BY ...)
```

| Argument       | Meaning                                            | Default  |
| -------------- | -------------------------------------------------- | -------- |
| `expression` | The column or value to fetch                       | required |
| `offset`     | How many rows back (`LAG`) or forward (`LEAD`) | 1        |
| `default`    | Value to return if there's no such row             | `NULL` |

## Basic example

```sql
SELECT
    OrderID,
    OrderDate,
    Sales,
    LAG(Sales)        OVER (ORDER BY OrderDate) AS prev_sales,
    LEAD(Sales)       OVER (ORDER BY OrderDate) AS next_sales,
    LAG(Sales, 2, 0)  OVER (ORDER BY OrderDate) AS sales_2_back,
    LEAD(Sales, 2, 0) OVER (ORDER BY OrderDate) AS sales_2_ahead
FROM Sales.Orders;
```

| OrderID | OrderDate  | Sales | prev_sales | next_sales | sales_2_back | sales_2_ahead |
| ------- | ---------- | ----- | ---------- | ---------- | ------------ | ------------- |
| 1       | 2025-01-01 | 10    | NULL       | 15         | 0            | 20            |
| 2       | 2025-01-05 | 15    | 10         | 20         | 0            | 60            |
| 3       | 2025-01-10 | 20    | 15         | 60         | 10           | 25            |
| 4       | 2025-01-20 | 60    | 20         | 25         | 15           | 50            |
| 5       | 2025-02-01 | 25    | 60         | 50         | 20           | 30            |
| 6       | 2025-02-05 | 50    | 25         | 30         | 60           | 90            |
| 7       | 2025-02-10 | 30    | 50         | 90         | 25           | 20            |
| 8       | 2025-02-15 | 90    | 30         | 20         | 50           | 60            |
| 9       | 2025-03-01 | 20    | 90         | 60         | 30           | 40            |
| 10      | 2025-03-10 | 60    | 20         | 40         | 90           | 0             |
| 11      | 2025-03-20 | 40    | 60         | NULL       | 20           | 0             |

- `prev_sales` is `NULL` on the first row and `next_sales` is `NULL` on the last row.
- With offset 2 and default 0, the rows with no row two steps away get `0` instead of `NULL`.

---

## Use Case: Month-over-Month (MoM) Analysis

**Task:** analyse month-over-month performance by finding the change, and the percentage change, in sales between the current and previous month.

```sql
SELECT
    *,
    current_month_sale - previous_month_sales AS MoM_change,
    ROUND(CAST(current_month_sale - previous_month_sales AS FLOAT)
          / previous_month_sales * 100, 1)    AS percentage
FROM (
    SELECT
        MONTH(OrderDate)           AS month_number,
        DATENAME(MONTH, OrderDate) AS order_month,
        SUM(Sales)                 AS current_month_sale,
        LAG(SUM(Sales)) OVER (ORDER BY MONTH(OrderDate)) AS previous_month_sales
    FROM Sales.Orders
    GROUP BY MONTH(OrderDate), DATENAME(MONTH, OrderDate)
) AS t
ORDER BY month_number;
```

| month_number | order_month | current_month_sale | previous_month_sales | MoM_change | percentage |
| ------------ | ----------- | ------------------ | -------------------- | ---------- | ---------- |
| 1            | January     | 105                | NULL                 | NULL       | NULL       |
| 2            | February    | 195                | 105                  | 90         | 85.7       |
| 3            | March       | 120                | 195                  | -75        | -38.5      |

**How it works:**

- `GROUP BY` first collapses the orders to one row per month. `LAG(SUM(Sales))` then runs on those grouped rows and fetches the previous month's total.
- **Order by `MONTH(OrderDate)`, not `DATENAME`.** Month names sort alphabetically (February, January, March), so each month would be compared with the wrong one.
- `DATENAME(MONTH, ...)` is in the `GROUP BY` because every non-aggregated column in `SELECT` must be grouped, even with a window function.
- **January is `NULL`** because it has no previous month. That's expected.
- **Cast to `FLOAT` before dividing.** Integer division would truncate the percentage to a whole number.
- **Protect against a zero previous month:** `/ NULLIF(previous_month_sales, 0)` returns `NULL` instead of a divide-by-zero error.
- Percentage change = (current − previous) / previous × 100. February's 90 on a base of 105 is +85.7%.

**Year-over-year (YoY):** same idea at the year level:

```sql
SELECT
    YEAR(OrderDate) AS order_year,
    SUM(Sales)      AS current_year_sales,
    LAG(SUM(Sales)) OVER (ORDER BY YEAR(OrderDate)) AS previous_year_sales
FROM Sales.Orders
GROUP BY YEAR(OrderDate);
```

> **Multiple years?** Grouping by month number alone merges the same month from different years. Group by year **and** month (or by a real date such as `DATETRUNC(MONTH, OrderDate)` on SQL Server 2022+), and order by that. Using `LAG(x, 12)` for "same month last year" only works if no month is missing from the data.

---

## Use Case: Customer Retention Analysis

To analyse customer loyalty, measure how long customers wait between orders. A **shorter average gap means a more loyal customer.**

**Step 1: the gap between each order and the customer's next order:**

```sql
SELECT
    CustomerID,
    OrderID,
    OrderDate,
    LEAD(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS next_order_date,
    DATEDIFF(
        DAY,
        OrderDate,
        LEAD(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate)
    ) AS order_gap
FROM Sales.Orders;
```

| CustomerID | OrderID | OrderDate  | next_order_date | order_gap |
| ---------- | ------- | ---------- | --------------- | --------- |
| 1          | 3       | 2025-01-10 | 2025-01-20      | 10        |
| 1          | 4       | 2025-01-20 | 2025-02-10      | 21        |
| 1          | 7       | 2025-02-10 | 2025-03-01      | 19        |
| 1          | 9       | 2025-03-01 | NULL            | NULL      |
| 2          | 1       | 2025-01-01 | 2025-02-01      | 31        |
| 2          | 5       | 2025-02-01 | 2025-03-10      | 37        |
| 2          | 10      | 2025-03-10 | NULL            | NULL      |
| 3          | 2       | 2025-01-05 | 2025-02-05      | 31        |
| 3          | 6       | 2025-02-05 | 2025-02-15      | 10        |
| 3          | 8       | 2025-02-15 | NULL            | NULL      |
| 4          | 11      | 2025-03-20 | NULL            | NULL      |

`PARTITION BY CustomerID` keeps customers separate, so each customer's last order has no next order (`NULL`).

**Step 2: average the gaps and rank the customers:**

```sql
SELECT
    CustomerID,
    AVG(order_gap) AS avg_days,
    RANK() OVER (ORDER BY COALESCE(AVG(order_gap), 99999)) AS rank_avg
FROM (
    SELECT
        CustomerID,
        OrderID,
        OrderDate,
        LEAD(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS next_order_date,
        DATEDIFF(
            DAY,
            OrderDate,
            LEAD(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate)
        ) AS order_gap
    FROM Sales.Orders
) AS t
GROUP BY CustomerID;
```

| CustomerID | avg_days | rank_avg |
| ---------- | -------- | -------- |
| 1          | 16       | 1        |
| 3          | 20       | 2        |
| 2          | 34       | 3        |
| 4          | NULL     | 4        |

**How it works:**

- **`AVG` ignores the `NULL` gaps**, so a customer's last order doesn't distort the average.
- **Customer 4 has only one order**, so there are no gaps and the average is `NULL`. `COALESCE(..., 99999)` replaces that with a huge number so they're ranked **last** instead of first. In SQL Server `NULL` sorts first in ascending order.
- `RANK() OVER (ORDER BY AVG(...))` works because the window function runs after `GROUP BY`, so it can rank the grouped results.
- A `CASE` sort avoids the magic number: `ORDER BY CASE WHEN AVG(order_gap) IS NULL THEN 1 ELSE 0 END, AVG(order_gap)`.

> ⚠️ **`DATEDIFF` returns an `INT`, so `AVG` truncates.** Customer 1's real average is 16.67, shown here as 16. Truncating can create **false ties** in the ranking (16.2 and 16.9 both become 16). Cast first for exact values:
>
> ```sql
> AVG(CAST(order_gap AS FLOAT)) AS avg_days
> ```
>
> **Aliases can't be reused in the same `SELECT`.** You can't write `DATEDIFF(DAY, OrderDate, next_order_date)` right after defining `next_order_date` in the same list. Repeat the `LEAD(...)` (as above) or compute it in an inner subquery.

---

# FIRST_VALUE and LAST_VALUE

`FIRST_VALUE(expr)` and `LAST_VALUE(expr)` return a value from the **first** or **last row of the window**. What counts as "first" and "last" is decided by `ORDER BY` inside `OVER`, and, for `LAST_VALUE`, by the frame.

## FIRST_VALUE

```sql
-- the lowest sale for each product, next to every order
SELECT
    OrderID,
    ProductID,
    Sales,
    FIRST_VALUE(Sales) OVER (PARTITION BY ProductID ORDER BY Sales) AS lowest_sales
FROM Sales.Orders;
```

| OrderID | ProductID | Sales | lowest_sales |
| ------- | --------- | ----- | ------------ |
| 1       | 101       | 10    | 10           |
| 3       | 101       | 20    | 10           |
| 9       | 101       | 20    | 10           |
| 8       | 101       | 90    | 10           |
| 2       | 102       | 15    | 15           |
| 7       | 102       | 30    | 15           |
| 10      | 102       | 60    | 15           |
| 11      | 103       | 40    | 40           |
| 5       | 104       | 25    | 25           |
| 6       | 104       | 50    | 25           |
| 4       | 105       | 60    | 60           |

Sorting ascending puts the smallest sale first, so `FIRST_VALUE` is the minimum. With the default frame this works as expected, because the first row is always inside the frame.

## LAST_VALUE and the frame trap

You'd expect `LAST_VALUE` with the same ordering to give the **highest** sale. With the default frame it doesn't:

```sql
SELECT
    OrderID,
    ProductID,
    Sales,
    LAST_VALUE(Sales) OVER (PARTITION BY ProductID ORDER BY Sales) AS last_default,
    LAST_VALUE(Sales) OVER (
        PARTITION BY ProductID
        ORDER BY Sales
        ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
    ) AS highest_sales,
    FIRST_VALUE(Sales) OVER (PARTITION BY ProductID ORDER BY Sales DESC) AS highest_via_first
FROM Sales.Orders;
```

| OrderID | ProductID | Sales | last_default | highest_sales | highest_via_first |
| ------- | --------- | ----- | ------------ | ------------- | ----------------- |
| 1       | 101       | 10    | **10** | 90            | 90                |
| 3       | 101       | 20    | **20** | 90            | 90                |
| 9       | 101       | 20    | **20** | 90            | 90                |
| 8       | 101       | 90    | 90           | 90            | 90                |
| 2       | 102       | 15    | **15** | 60            | 60                |
| 7       | 102       | 30    | **30** | 60            | 60                |
| 10      | 102       | 60    | 60           | 60            | 60                |
| 5       | 104       | 25    | **25** | 50            | 50                |
| 6       | 104       | 50    | 50           | 50            | 50                |

**Why `last_default` is wrong:** with an `ORDER BY` and no frame, the default frame is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. The "last row of the window" is therefore always the **current row** (or the last row with the same sort value), so `LAST_VALUE` just repeats `Sales`.

**Two fixes:**

1. **Extend the frame to the end of the partition:**

   ```sql
   LAST_VALUE(Sales) OVER (
       PARTITION BY ProductID
       ORDER BY Sales
       ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
   )
   ```

   `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` (the whole partition) also works.
2. **Use `FIRST_VALUE` with the opposite sort order.** Sorting `DESC` makes the highest sale the first row, so no frame is needed:

   ```sql
   FIRST_VALUE(Sales) OVER (PARTITION BY ProductID ORDER BY Sales DESC)
   ```

   Many people prefer this because it avoids the frame trap.

> If you just need the overall min or max, `MIN(Sales) OVER (PARTITION BY ProductID)` and `MAX(...)` are simpler. `FIRST_VALUE`/`LAST_VALUE` shine when you want a **different column** from the first or last row, for example the date or ID of the latest order:
>
> ```sql
> FIRST_VALUE(OrderID) OVER (PARTITION BY ProductID ORDER BY OrderDate DESC) AS latest_order_id
> ```

## Use Case: Compare Each Row to the Lowest and Highest

```sql
-- how far each sale is above the lowest sale for its product
SELECT
    OrderID,
    ProductID,
    Sales,
    FIRST_VALUE(Sales) OVER (PARTITION BY ProductID ORDER BY Sales) AS lowest_sales,
    Sales - FIRST_VALUE(Sales) OVER (PARTITION BY ProductID ORDER BY Sales) AS diff_from_lowest
FROM Sales.Orders;
```

| OrderID | ProductID | Sales | lowest_sales | diff_from_lowest |
| ------- | --------- | ----- | ------------ | ---------------- |
| 1       | 101       | 10    | 10           | 0                |
| 3       | 101       | 20    | 10           | 10               |
| 9       | 101       | 20    | 10           | 10               |
| 8       | 101       | 90    | 10           | 80               |
| 2       | 102       | 15    | 15           | 0                |
| 7       | 102       | 30    | 15           | 15               |
| 10      | 102       | 60    | 15           | 45               |
| 11      | 103       | 40    | 40           | 0                |
| 5       | 104       | 25    | 25           | 0                |
| 6       | 104       | 50    | 25           | 25               |
| 4       | 105       | 60    | 60           | 0                |

---

## Common Gotchas

1. **Missing `ORDER BY`.** All four functions need it in `OVER`. Without it you get an error, or no meaningful "previous/first".
2. **Forgetting `PARTITION BY`.** The lookup then crosses group boundaries (one customer's last row feeds the next customer's first row).
3. **`LAST_VALUE` returns the current row.** The default frame ends at the current row. Use `ROWS BETWEEN ... AND UNBOUNDED FOLLOWING`, or flip the sort and use `FIRST_VALUE`.
4. **Sorting by month names.** `ORDER BY DATENAME(MONTH, ...)` is alphabetical. Sort by `MONTH(...)` or a real date.
5. **First/last rows are `NULL`.** `LAG` on the first row and `LEAD` on the last row return `NULL` unless you give a default. Math with that `NULL` (like a change or percentage) is also `NULL`.
6. **Missing periods.** `LAG`/`LEAD` jump by **rows**, not by time. If a month has no data, the "previous" row is two months back. Fill the gaps first (for example with a calendar table).
7. **Integer division and truncation.** Cast to `FLOAT` for percentages and averages (`AVG` of `DATEDIFF` results truncates).
8. **Dividing by zero.** Use `NULLIF(previous, 0)` for percentage change.
9. **Aliases can't be reused in the same `SELECT`.** Wrap in a subquery or repeat the expression.
10. **`NULL` values in the column itself.** By default `LAG`/`LEAD`/`FIRST_VALUE`/`LAST_VALUE` return `NULL` if that row's value is `NULL`. SQL Server 2022+ supports `IGNORE NULLS` to skip them (`LAG(Sales) IGNORE NULLS OVER (...)`).

---

## Cheat Sheet

| I want...                            | Use                                                                                                 |
| ------------------------------------ | --------------------------------------------------------------------------------------------------- |
| The previous row's value             | `LAG(x) OVER (ORDER BY d)`                                                                        |
| The next row's value                 | `LEAD(x) OVER (ORDER BY d)`                                                                       |
| Two rows back,`0` if none          | `LAG(x, 2, 0) OVER (ORDER BY d)`                                                                  |
| Previous value within each group     | `LAG(x) OVER (PARTITION BY g ORDER BY d)`                                                         |
| Month-over-month change              | `SUM(x) - LAG(SUM(x)) OVER (ORDER BY MONTH(d))` after `GROUP BY`                                |
| Percentage change                    | `(cur - prev) * 100.0 / NULLIF(prev, 0)`                                                          |
| Days until the customer's next order | `DATEDIFF(DAY, d, LEAD(d) OVER (PARTITION BY c ORDER BY d))`                                      |
| First value in each group            | `FIRST_VALUE(x) OVER (PARTITION BY g ORDER BY d)`                                                 |
| Last value in each group             | `LAST_VALUE(x) OVER (PARTITION BY g ORDER BY d ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)` |
| Last value, no frame needed          | `FIRST_VALUE(x) OVER (PARTITION BY g ORDER BY d DESC)`                                            |

| Function        | Looks at                       | `NULL` when                          | Frame matters?                                        |
| --------------- | ------------------------------ | -------------------------------------- | ----------------------------------------------------- |
| `LAG`         | Previous row                   | No previous row (unless default given) | No                                                    |
| `LEAD`        | Next row                       | No next row (unless default given)     | No                                                    |
| `FIRST_VALUE` | First row of the window        | The first row's value is`NULL`       | Yes                                                   |
| `LAST_VALUE`  | Last row of the**frame** | The last row's value is`NULL`        | **Yes (default frame ends at the current row)** |
