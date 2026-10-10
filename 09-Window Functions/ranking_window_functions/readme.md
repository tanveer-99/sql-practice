
# SQL Ranking Window Functions

A quick reference for ranking in T-SQL (SQL Server): `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE` (integer-based) and `CUME_DIST`, `PERCENT_RANK` (percentage-based). Includes top/bottom N, unique IDs, duplicate removal, segmentation and load splitting.

Ranking functions are window functions, so they **keep every row** and add a rank column. See the [window functions README](sql-window-functions.md) for `OVER` basics.

---

## Table of Contents

- [Important Notes](#important-notes)
- [Overview](#overview)
- [Sample Data](#sample-data)
- [Integer-Based Ranking](#integer-based-ranking)
  - [ROW_NUMBER](#row_number) · [RANK](#rank) · [DENSE_RANK](#dense_rank) · [Comparison](#comparison)
- [Use Cases](#use-cases)
  - [Top N analysis](#use-case-top-n-analysis) · [Bottom N analysis](#use-case-bottom-n-analysis) · [Unique IDs and pagination](#use-case-assign-unique-ids-and-pagination) · [Remove duplicates](#use-case-identify-and-remove-duplicates)
- [NTILE](#ntile)
  - [Data segmentation](#use-case-data-segmentation) · [Load balancing (ETL)](#use-case-equalizing-load-processing-etl)
- [Percentage-Based Ranking](#percentage-based-ranking)
  - [CUME_DIST](#cume_dist) · [PERCENT_RANK](#percent_rank) · [Top 40% of prices](#use-case-top-40-of-prices)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Important Notes

1. **All ranking functions require `ORDER BY` inside `OVER`**, because a rank needs an order. `PARTITION BY` is optional and restarts the ranking for each group.
2. **`ROW_NUMBER` never ties.** `RANK` and `DENSE_RANK` give tied rows the same number. They differ in what comes **after** a tie: `RANK` skips numbers (1, 2, 2, **4**), `DENSE_RANK` doesn't (1, 2, 2, **3**).
3. **Ties make `ROW_NUMBER` and `NTILE` non-deterministic.** Which tied row gets which number isn't guaranteed. Add a tiebreaker column to `ORDER BY` (`ORDER BY Sales DESC, OrderID`) if you need repeatable results.
4. **You can't filter on a rank in `WHERE`.** Wrap the query in a subquery or CTE, then filter on the rank alias. This is the basis of all top-N and de-duplication patterns.
5. **Top N per group = `ROW_NUMBER` + `PARTITION BY` + filter.** Use `RANK`/`DENSE_RANK` instead if tied rows should all be kept.
6. **`CUME_DIST` includes the current row, `PERCENT_RANK` excludes it.** `CUME_DIST` ranges from just above 0 up to 1. `PERCENT_RANK` ranges from 0 up to 1.
7. **`NTILE(n)` makes bucket *sizes* as equal as possible**, not value ranges. If the rows don't divide evenly, the **first buckets get one extra row**.

---

## Overview

| Type                       | Function           | What it does                                                     |
| -------------------------- | ------------------ | ---------------------------------------------------------------- |
| **Integer-based**    | `ROW_NUMBER()`   | Unique number per row (1 to N), no ties                          |
|                            | `RANK()`         | Rank with ties;**leaves gaps** after ties                  |
|                            | `DENSE_RANK()`   | Rank with ties;**no gaps**                                 |
|                            | `NTILE(n)`       | Divides rows into`n` roughly equal buckets                     |
| **Percentage-based** | `CUME_DIST()`    | Share of rows at or before the current row (**inclusive**) |
|                            | `PERCENT_RANK()` | Relative position of the row from 0 to 1 (**exclusive**)   |

Integer-based functions rank rows with whole numbers from 1 to N (or bucket numbers). Percentage-based functions describe where a row sits in the **distribution**.

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
    OrderID      INT,
    ProductID    INT,
    OrderDate    DATE,
    Sales        INT,
    CreationTime DATETIME2
);

INSERT INTO Sales.OrdersArchive VALUES
(1, 101, '2024-01-05', 10, '2024-01-05 09:00:00'),
(2, 102, '2024-01-20', 15, '2024-01-20 10:30:00'),
(3, 101, '2024-02-02', 20, '2024-02-02 14:15:00'),
(4, 105, '2024-02-10', 60, '2024-02-10 11:00:00'),
(4, 105, '2024-02-10', 60, '2024-02-10 11:05:00'),   -- duplicate OrderID
(5, 104, '2024-03-01', 25, '2024-03-01 08:45:00'),
(6, 104, '2024-03-15', 50, '2024-03-15 16:20:00'),
(6, 104, '2024-03-16', 55, '2024-03-16 09:10:00');   -- duplicate OrderID

CREATE TABLE Sales.Products (
    ProductID INT PRIMARY KEY,
    Product   VARCHAR(50),
    Price     INT
);

INSERT INTO Sales.Products VALUES
(101, 'Bottle', 10),
(102, 'Tire',   15),
(103, 'Caps',   25),
(104, 'Gloves', 30),
(105, 'Helmet', 30);
```

**Sales.Orders**, sorted by sales (note the **ties**: two 60s and two 20s)

| OrderID | ProductID | Sales |
| ------- | --------- | ----- |
| 8       | 101       | 90    |
| 4       | 105       | 60    |
| 10      | 102       | 60    |
| 6       | 104       | 50    |
| 7       | 102       | 30    |
| 5       | 104       | 25    |
| 3       | 101       | 20    |
| 9       | 101       | 20    |
| 2       | 102       | 15    |
| 1       | 101       | 10    |

> Where rows tie, SQL Server may return them in a different order than shown (see [Important Notes](#important-notes), point 3). The tables below show tied rows in `OrderID` order.

---

# Integer-Based Ranking

Ranks rows with distinct (or shared) numbers from 1 to N. Functions: `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `NTILE()`.

## ROW_NUMBER

Assigns a **unique, sequential number** to each row. It doesn't handle ties: tied rows still get different numbers.

```sql
-- rank the orders by sales, highest first
SELECT
    OrderID,
    ProductID,
    Sales,
    ROW_NUMBER() OVER (ORDER BY Sales DESC) AS sales_rank_row
FROM Sales.Orders;
```

| OrderID | ProductID | Sales | sales_rank_row |
| ------- | --------- | ----- | -------------- |
| 8       | 101       | 90    | 1              |
| 4       | 105       | 60    | 2              |
| 10      | 102       | 60    | 3              |
| 6       | 104       | 50    | 4              |
| 7       | 102       | 30    | 5              |
| 5       | 104       | 25    | 6              |
| 3       | 101       | 20    | 7              |
| 9       | 101       | 20    | 8              |
| 2       | 102       | 15    | 9              |
| 1       | 101       | 10    | 10             |

Orders 4 and 10 both have sales of 60, but they get 2 and 3.

## RANK

Assigns a rank to each row and **handles ties**: tied rows share the same rank, and the **next rank skips ahead** (leaves gaps). The numbers still increase in order.

```sql
SELECT
    OrderID,
    ProductID,
    Sales,
    ROW_NUMBER() OVER (ORDER BY Sales DESC) AS sales_rank_row,
    RANK()       OVER (ORDER BY Sales DESC) AS sales_rank
FROM Sales.Orders;
```

| OrderID | ProductID | Sales | sales_rank_row | sales_rank  |
| ------- | --------- | ----- | -------------- | ----------- |
| 8       | 101       | 90    | 1              | 1           |
| 4       | 105       | 60    | 2              | **2** |
| 10      | 102       | 60    | 3              | **2** |
| 6       | 104       | 50    | 4              | **4** |
| 7       | 102       | 30    | 5              | 5           |
| 5       | 104       | 25    | 6              | 6           |
| 3       | 101       | 20    | 7              | **7** |
| 9       | 101       | 20    | 8              | **7** |
| 2       | 102       | 15    | 9              | **9** |
| 1       | 101       | 10    | 10             | 10          |

Two rows share rank 2, so rank 3 doesn't exist and the next is 4. This matches how competitions work: two joint silver medals means no bronze.

## DENSE_RANK

Like `RANK`, tied rows share a rank, but it **doesn't leave gaps**.

```sql
SELECT
    OrderID,
    ProductID,
    Sales,
    DENSE_RANK() OVER (ORDER BY Sales DESC) AS sales_dense_rank
FROM Sales.Orders;
```

| OrderID | ProductID | Sales | sales_dense_rank |
| ------- | --------- | ----- | ---------------- |
| 8       | 101       | 90    | 1                |
| 4       | 105       | 60    | 2                |
| 10      | 102       | 60    | 2                |
| 6       | 104       | 50    | 3                |
| 7       | 102       | 30    | 4                |
| 5       | 104       | 25    | 5                |
| 3       | 101       | 20    | 6                |
| 9       | 101       | 20    | 6                |
| 2       | 102       | 15    | 7                |
| 1       | 101       | 10    | 8                |

The rank after the tie at 2 is 3, so `DENSE_RANK` ends at 8 (the number of **distinct** sales values), not 10.

## Comparison

| Sales | `ROW_NUMBER` | `RANK` | `DENSE_RANK` |
| ----- | -------------- | -------- | -------------- |
| 90    | 1              | 1        | 1              |
| 60    | 2              | 2        | 2              |
| 60    | 3              | 2        | 2              |
| 50    | 4              | 4        | 3              |
| 30    | 5              | 5        | 4              |

|                      | `ROW_NUMBER`                    | `RANK`                     | `DENSE_RANK`                |
| -------------------- | --------------------------------- | ---------------------------- | ----------------------------- |
| Ties share a number? | No                                | Yes                          | Yes                           |
| Gaps after ties?     | n/a                               | **Yes**                | No                            |
| Highest number       | N (row count)                     | N (row count)                | Number of distinct values     |
| Use when             | You need exactly one row per rank | Standard competition ranking | "Nth highest value" questions |

---

# Use Cases

## Use Case: Top N Analysis

**Task:** find the highest sale for each product.

```sql
SELECT *
FROM (
    SELECT
        OrderID,
        ProductID,
        Sales,
        ROW_NUMBER() OVER (PARTITION BY ProductID ORDER BY Sales DESC) AS rank_by_product
    FROM Sales.Orders
) AS t
WHERE rank_by_product = 1;
```

| OrderID | ProductID | Sales | rank_by_product |
| ------- | --------- | ----- | --------------- |
| 8       | 101       | 90    | 1               |
| 10      | 102       | 60    | 1               |
| 6       | 104       | 50    | 1               |
| 4       | 105       | 60    | 1               |

**How it works:**

- `PARTITION BY ProductID` restarts the numbering for each product.
- `ORDER BY Sales DESC` puts the biggest sale first, so it gets 1.
- The outer `WHERE` keeps only row 1. The subquery is required because you can't filter on a window function directly.

**Top 2 per product:** change the filter to `rank_by_product <= 2`.

| OrderID | ProductID | Sales | rank_by_product |
| ------- | --------- | ----- | --------------- |
| 8       | 101       | 90    | 1               |
| 3       | 101       | 20    | 2               |
| 10      | 102       | 60    | 1               |
| 7       | 102       | 30    | 2               |
| 6       | 104       | 50    | 1               |
| 5       | 104       | 25    | 2               |
| 4       | 105       | 60    | 1               |

Product 105 has only one order, so it appears once.

**Top N overall (not per group):** drop the `PARTITION BY`, or use `SELECT TOP (n) ... ORDER BY Sales DESC`.

> **Ties:** `ROW_NUMBER() = 1` returns exactly one row per product, even if two orders tie for the top. To return all tied top rows, use `RANK() ... = 1` or `DENSE_RANK() ... = 1`.

## Use Case: Bottom N Analysis

Flip the sort order to `ASC`. Helps analyse **underperformance**, manage risks and find optimisation targets.

```sql
-- lowest sale for each product
SELECT *
FROM (
    SELECT
        OrderID,
        ProductID,
        Sales,
        ROW_NUMBER() OVER (PARTITION BY ProductID ORDER BY Sales ASC) AS rank_by_product
    FROM Sales.Orders
) AS t
WHERE rank_by_product = 1;
```

| OrderID | ProductID | Sales | rank_by_product |
| ------- | --------- | ----- | --------------- |
| 1       | 101       | 10    | 1               |
| 2       | 102       | 15    | 1               |
| 5       | 104       | 25    | 1               |
| 4       | 105       | 60    | 1               |

## Use Case: Assign Unique IDs and Pagination

`ROW_NUMBER()` gives each row a unique identifier. This helps with **pagination**: breaking a large dataset into smaller, manageable chunks (pages).

```sql
-- assign unique IDs to the rows of the archive table
SELECT
    ROW_NUMBER() OVER (ORDER BY OrderID, OrderDate) AS unique_id,
    *
FROM Sales.OrdersArchive;
```

| unique_id | OrderID | ProductID | OrderDate  | Sales | CreationTime        |
| --------- | ------- | --------- | ---------- | ----- | ------------------- |
| 1         | 1       | 101       | 2024-01-05 | 10    | 2024-01-05 09:00:00 |
| 2         | 2       | 102       | 2024-01-20 | 15    | 2024-01-20 10:30:00 |
| 3         | 3       | 101       | 2024-02-02 | 20    | 2024-02-02 14:15:00 |
| 4         | 4       | 105       | 2024-02-10 | 60    | 2024-02-10 11:00:00 |
| 5         | 4       | 105       | 2024-02-10 | 60    | 2024-02-10 11:05:00 |
| 6         | 5       | 104       | 2024-03-01 | 25    | 2024-03-01 08:45:00 |
| 7         | 6       | 104       | 2024-03-15 | 50    | 2024-03-15 16:20:00 |
| 8         | 6       | 104       | 2024-03-16 | 55    | 2024-03-16 09:10:00 |

**Pagination:** pick a page by filtering the row number (page size 3, page 2 = rows 4 to 6):

```sql
SELECT *
FROM (
    SELECT
        ROW_NUMBER() OVER (ORDER BY OrderID, OrderDate) AS unique_id,
        *
    FROM Sales.OrdersArchive
) AS t
WHERE unique_id BETWEEN 4 AND 6;
```

SQL Server also has built-in paging: `ORDER BY OrderID, OrderDate OFFSET 3 ROWS FETCH NEXT 3 ROWS ONLY`.

> The `ORDER BY` decides the numbering. Make it **deterministic** (include a unique column) or rows 4 and 5 above could swap IDs between runs. SQL Server requires an `ORDER BY` in `ROW_NUMBER`. If you don't care about order, use `ORDER BY (SELECT NULL)`.

## Use Case: Identify and Remove Duplicates

**Task:** identify duplicate rows in the archive and return a clean result with no duplicates.

Number the rows **within each duplicate group**, newest first, then keep only row 1:

```sql
SELECT *
FROM (
    SELECT
        ROW_NUMBER() OVER (PARTITION BY OrderID ORDER BY CreationTime DESC) AS rn,
        *
    FROM Sales.OrdersArchive
) AS t
WHERE rn = 1;
```

| rn | OrderID | ProductID | OrderDate  | Sales | CreationTime        |
| -- | ------- | --------- | ---------- | ----- | ------------------- |
| 1  | 1       | 101       | 2024-01-05 | 10    | 2024-01-05 09:00:00 |
| 1  | 2       | 102       | 2024-01-20 | 15    | 2024-01-20 10:30:00 |
| 1  | 3       | 101       | 2024-02-02 | 20    | 2024-02-02 14:15:00 |
| 1  | 4       | 105       | 2024-02-10 | 60    | 2024-02-10 11:05:00 |
| 1  | 5       | 104       | 2024-03-01 | 25    | 2024-03-01 08:45:00 |
| 1  | 6       | 104       | 2024-03-16 | 55    | 2024-03-16 09:10:00 |

For each `OrderID` this keeps the **latest** record (highest `CreationTime`).

**Notes:**

- **Choosing the survivor:** the `ORDER BY` inside `OVER` decides which duplicate is kept. `CreationTime DESC` = newest, `ASC` = oldest.
- **Partition by the right columns:** `PARTITION BY OrderID` treats rows with the same ID as duplicates even if other columns differ (like order 6). To treat only fully identical rows as duplicates, partition by all columns.
- **Just see the duplicates?** Use `rn > 1` to list the rows that would be removed.
- **Delete them for real** (SQL Server lets you delete through a CTE):

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

# NTILE

`NTILE(n)` divides the rows into `n` **approximately equal groups (buckets)** and returns the bucket number (1 to n).

```sql
SELECT
    OrderID,
    Sales,
    NTILE(3) OVER (ORDER BY Sales DESC) AS bucket
FROM Sales.Orders;
```

| OrderID | Sales | bucket |
| ------- | ----- | ------ |
| 8       | 90    | 1      |
| 4       | 60    | 1      |
| 10      | 60    | 1      |
| 6       | 50    | 1      |
| 7       | 30    | 2      |
| 5       | 25    | 2      |
| 3       | 20    | 2      |
| 9       | 20    | 3      |
| 2       | 15    | 3      |
| 1       | 10    | 3      |

**How the size works:** 10 rows into 3 buckets doesn't divide evenly (10 / 3 = 3 remainder 1), so the **extra row goes to the first bucket**: sizes 4, 3, 3. With 11 rows it would be 4, 4, 3.

> ⚠️ **Ties get split across buckets.** Orders 3 and 9 both have sales of 20, but one lands in bucket 2 and the other in bucket 3. `NTILE` counts **rows**, it doesn't look at values. Which of the two goes where isn't guaranteed unless you add a tiebreaker to the `ORDER BY`.

## Use Case: Data Segmentation

As a **data analyst**, use `NTILE` to segment data into categories. **Task:** segment all orders into High, Medium and Low.

```sql
SELECT
    *,
    CASE
        WHEN bucket = 1 THEN 'High'
        WHEN bucket = 2 THEN 'Medium'
        WHEN bucket = 3 THEN 'Low'
    END AS sales_segment
FROM (
    SELECT
        OrderID,
        Sales,
        NTILE(3) OVER (ORDER BY Sales DESC) AS bucket
    FROM Sales.Orders
) AS t;
```

| OrderID | Sales | bucket | sales_segment |
| ------- | ----- | ------ | ------------- |
| 8       | 90    | 1      | High          |
| 4       | 60    | 1      | High          |
| 10      | 60    | 1      | High          |
| 6       | 50    | 1      | High          |
| 7       | 30    | 2      | Medium        |
| 5       | 25    | 2      | Medium        |
| 3       | 20    | 2      | Medium        |
| 9       | 20    | 3      | Low           |
| 2       | 15    | 3      | Low           |
| 1       | 10    | 3      | Low           |

Because the sort is descending, bucket 1 holds the highest sales. These segments are based on **rank position** (top third, middle third, bottom third), not on fixed thresholds. If you want "High means over 50", use `CASE WHEN Sales > 50` instead.

## Use Case: Equalizing Load Processing (ETL)

As a **data engineer**, use `NTILE` for load balancing. When moving a large dataset from one place to another, sending everything at once can fail or time out. Splitting the data into **buckets** lets you ship it in manageable, similar-sized batches, and combine the results at the end (for example with `UNION ALL`).

```sql
-- split the table into 4 batches of similar size
SELECT
    *,
    NTILE(4) OVER (ORDER BY OrderID) AS batch_id
FROM Sales.OrdersArchive;

-- process one batch at a time
SELECT OrderID, ProductID, OrderDate, Sales, CreationTime
FROM (
    SELECT *, NTILE(4) OVER (ORDER BY OrderID) AS batch_id
    FROM Sales.OrdersArchive
) AS t
WHERE batch_id = 1;     -- then 2, 3 and 4
```

Order by a **unique, stable key** (`OrderID`, or a surrogate key) so each batch is repeatable and no row lands in two batches. Use `UNION ALL` (not `UNION`) when recombining, since the batches don't overlap and it skips the duplicate-removal step.

---

# Percentage-Based Ranking

Describes **where a row sits in the distribution** of a column, as a value between 0 and 1. Functions: `CUME_DIST()` and `PERCENT_RANK()`.

|             | `CUME_DIST()`                                     | `PERCENT_RANK()`              |
| ----------- | --------------------------------------------------- | ------------------------------- |
| Meaning     | Share of rows**at or before** the current row | Relative position of the row    |
| Current row | **Included** (inclusive)                      | **Excluded** (exclusive)  |
| Formula     | rows with value ≤ current / total rows             | (rank − 1) / (total rows − 1) |
| Range       | just above 0 to 1                                   | 0 to 1                          |
| First row   | 1 / N (never 0)                                     | Always 0                        |
| Last row    | Always 1                                            | Always 1                        |
| Ties        | Tied rows share the same value                      | Tied rows share the same value  |

```sql
SELECT
    Product,
    Price,
    CUME_DIST()    OVER (ORDER BY Price DESC) AS cume_dist,
    PERCENT_RANK() OVER (ORDER BY Price DESC) AS percent_rank
FROM Sales.Products;
```

| Product | Price | cume_dist | percent_rank |
| ------- | ----- | --------- | ------------ |
| Gloves  | 30    | 0.4       | 0            |
| Helmet  | 30    | 0.4       | 0            |
| Caps    | 25    | 0.6       | 0.5          |
| Tire    | 15    | 0.8       | 0.75         |
| Bottle  | 10    | 1         | 1            |

## CUME_DIST

For each row: *what fraction of rows have a value at or above this one* (with `DESC`)?

- Gloves and Helmet tie at the top. Both are included, so 2 / 5 = **0.4** for both.
- Caps: 3 rows (30, 30, 25) at or before it, so 3 / 5 = **0.6**.
- Bottle is the last row, so 5 / 5 = **1**.

## PERCENT_RANK

`(rank − 1) / (rows − 1)`, where `rank` is the `RANK()` value.

- Gloves and Helmet: rank 1, so (1 − 1) / (5 − 1) = **0**.
- Caps: rank 3, so (3 − 1) / 4 = **0.5**.
- Tire: rank 4, so 3 / 4 = **0.75**.
- Bottle: rank 5, so 4 / 4 = **1**.

Because the current row is excluded from the count, the top row is always 0 (nothing is ranked above it).

## Use Case: Top 40% of Prices

**Task:** find the products that fall within the highest 40% of prices.

```sql
SELECT
    *,
    CONCAT(dist_rank * 100, '%') AS dist_rank_percentage
FROM (
    SELECT
        Product,
        Price,
        CUME_DIST() OVER (ORDER BY Price DESC) AS dist_rank
    FROM Sales.Products
) AS t
WHERE dist_rank <= 0.4;
```

| Product | Price | dist_rank | dist_rank_percentage |
| ------- | ----- | --------- | -------------------- |
| Gloves  | 30    | 0.4       | 40%                  |
| Helmet  | 30    | 0.4       | 40%                  |

**How it works:**

- Sorting `Price DESC` puts the most expensive first, so `CUME_DIST <= 0.4` means "the top 40% of rows".
- **Why `CUME_DIST` and not `PERCENT_RANK`?** `CUME_DIST` includes the current row, so `<= 0.4` means the rows making up the top 40%. `PERCENT_RANK` of the first row is always 0, which would make "top X%" filters behave differently.
- **Ties come together or not at all.** Gloves and Helmet share 0.4, so both are included. A boundary tie can push the result slightly over the requested percentage.
- The result depends on the `ORDER BY` direction. With `ASC` the same filter gives the **cheapest** 40%.

> `dist_rank * 100` is a `FLOAT`, so the text can show float noise for some values. To be safe, round it: `CONCAT(CAST(ROUND(dist_rank * 100, 0) AS INT), '%')`.

---

## Common Gotchas

1. **Filtering a rank in `WHERE`.** Not allowed. Use a subquery or CTE.
2. **Ties with `ROW_NUMBER`.** It always picks one, in an unspecified order. Add a tiebreaker to `ORDER BY` for repeatable results, or use `RANK`/`DENSE_RANK` to keep ties.
3. **`RANK` leaves gaps.** If you want "2nd highest value", `DENSE_RANK() = 2` is correct. `RANK() = 2` can return nothing when two rows tie for first.
4. **Top N per group needs `PARTITION BY`.** Without it, you get the top N overall.
5. **Sort direction.** `DESC` ranks the biggest as 1. `ASC` ranks the smallest as 1. Easy to flip by accident.
6. **`NTILE` buckets are by row count, not value.** Equal values can land in different buckets, and uneven row counts give the earlier buckets an extra row.
7. **De-duplicating:** the `PARTITION BY` columns define what a "duplicate" is, and the `ORDER BY` defines which one survives.
8. **`CUME_DIST` vs `PERCENT_RANK`:** they differ at the edges. `CUME_DIST` never returns 0, `PERCENT_RANK` always does for the first row.
9. **`NULL`s in the `ORDER BY` column** sort first in ascending order in SQL Server, so they get the best rank under `ASC` and the worst under `DESC`. Filter or `COALESCE` them first.
10. **Rank results aren't output order.** Add a final `ORDER BY` if you need sorted results.

---

## Cheat Sheet

| I want...                        | Use                                                                                     |
| -------------------------------- | --------------------------------------------------------------------------------------- |
| A unique number per row          | `ROW_NUMBER() OVER (ORDER BY ...)`                                                    |
| Rank with ties, gaps after ties  | `RANK() OVER (ORDER BY ... DESC)`                                                     |
| Rank with ties, no gaps          | `DENSE_RANK() OVER (ORDER BY ... DESC)`                                               |
| Top N per group                  | `ROW_NUMBER() OVER (PARTITION BY g ORDER BY x DESC)` in a subquery, `WHERE rn <= N` |
| Bottom N per group               | Same, with`ORDER BY x ASC`                                                            |
| Top N including ties             | `RANK()` or `DENSE_RANK()` instead of `ROW_NUMBER()`                              |
| Nth highest value                | `DENSE_RANK() = N`                                                                    |
| Unique IDs / pagination          | `ROW_NUMBER()` then `WHERE id BETWEEN a AND b` (or `OFFSET ... FETCH`)            |
| Remove duplicates                | `ROW_NUMBER() OVER (PARTITION BY key ORDER BY CreationTime DESC)`, keep `rn = 1`    |
| Split into n equal groups        | `NTILE(n) OVER (ORDER BY ...)`                                                        |
| Segment into High / Medium / Low | `NTILE(3)` + `CASE` on the bucket                                                   |
| Batches for ETL                  | `NTILE(n)` on a unique key, process each `batch_id`, recombine with `UNION ALL`   |
| Top X% of values                 | `CUME_DIST() OVER (ORDER BY x DESC)`, `WHERE dist <= 0.X`                           |
| Relative position from 0 to 1    | `PERCENT_RANK() OVER (ORDER BY x)`                                                    |

| Function         | Ties                     | Gaps | Output                         |
| ---------------- | ------------------------ | ---- | ------------------------------ |
| `ROW_NUMBER`   | Different numbers        | n/a  | 1 to N                         |
| `RANK`         | Same number              | Yes  | 1 to N                         |
| `DENSE_RANK`   | Same number              | No   | 1 to number of distinct values |
| `NTILE(n)`     | Can split across buckets | n/a  | 1 to n                         |
| `CUME_DIST`    | Same value               | n/a  | above 0 to 1                   |
| `PERCENT_RANK` | Same value               | n/a  | 0 to 1                         |
