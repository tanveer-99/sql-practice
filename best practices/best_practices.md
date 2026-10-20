
# SQL Performance Best Practices (T-SQL / SQL Server)

> 30 practices for faster queries and better table design, each with **why it works**, an example, and an honest verdict on how much it really matters.
> Sample-data outputs in the logic examples were verified by running them; performance claims should be confirmed on your own data (see the golden rule).

---

## Table of Contents

1. [Golden rule: measure, don&#39;t guess](#golden-rule-measure-dont-guess)
2. [Verdicts at a glance](#verdicts-at-a-glance)
3. [Fetching data (1-3)](#fetching-data)
4. [Filtering data (4-7)](#filtering-data)
5. [Joining data (8-16)](#joining-data)
6. [Aggregating data (17-18)](#aggregating-data)
7. [Subqueries (19-20)](#subqueries)
8. [Creating tables (21-25)](#creating-tables)
9. [Indexing (26-30)](#indexing)
10. [Cheat sheet](#cheat-sheet)

---

## Golden rule: measure, don't guess

> Always check the execution plan to confirm a performance improvement. If there's no improvement, optimize for **readability** instead.

Many "rules" below change the *text* of a query but not the *plan* SQL Server builds. The only way to know is to compare before and after:

```sql
SET STATISTICS IO ON;     -- logical reads per table (the number to compare)
SET STATISTICS TIME ON;   -- CPU and elapsed time

-- run version A, note the numbers
-- run version B, compare

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

Also view the **actual execution plan** (your query tool's plan button or `Ctrl+M` in SSMS) and look for:

| Plan clue                                        | Meaning                                                   |
| ------------------------------------------------ | --------------------------------------------------------- |
| Table Scan / Clustered Index Scan on a big table | Reading everything; maybe an index is missing or unusable |
| Index Seek                                       | Jumped straight to rows, usually good                     |
| Key Lookup (many)                                | Index doesn't cover the query                             |
| Estimated vs Actual rows far apart               | Bad statistics -> bad plan                                |
| Thick arrows, Sort, Spill warnings               | Large intermediate data, memory trouble                   |

**Pitfalls when testing**

- On a tiny table a scan can beat a seek. Test with realistic data volumes.
- Compare **logical reads**, not just time. The second run is faster simply because data is cached.
- Change one thing at a time.

---

## Verdicts at a glance

| Label          | Meaning                                         |
| -------------- | ----------------------------------------------- |
| ✅ Solid       | True and usually matters                        |
| ⚠️ Caveats   | Right idea, but conditions apply                |
| 📖 Readability | Good habit, but SQL Server runs it the same way |
| ❌ Misleading  | Doesn't hold as written (corrected below)       |

| #  | Practice                                                | Verdict                    |
| -- | ------------------------------------------------------- | -------------------------- |
| 1  | Select only what you need, not `*`                    | ✅                         |
| 2  | Avoid unnecessary `DISTINCT` and `ORDER BY`         | ✅                         |
| 3  | Limit rows when exploring                               | ✅                         |
| 4  | Nonclustered index on frequent `WHERE` columns        | ✅                         |
| 5  | Don't wrap columns in functions in `WHERE`            | ✅                         |
| 6  | Avoid leading wildcards                                 | ✅                         |
| 7  | `IN` instead of multiple `OR`                       | 📖                         |
| 8  | Prefer `INNER JOIN` when possible                     | ⚠️                       |
| 9  | Explicit ANSI joins, not implicit                       | 📖                         |
| 10 | Index the `ON` columns                                | ✅                         |
| 11 | Filter before joining                                   | ⚠️                       |
| 12 | Aggregate before joining                                | ⚠️                       |
| 13 | `UNION` instead of `OR` in joins                    | ⚠️                       |
| 14 | Check nested loops, use hints                           | ⚠️ (hints = last resort) |
| 15 | `UNION ALL` instead of `UNION` if duplicates are OK | ✅                         |
| 16 | `UNION ALL` + `DISTINCT` instead of `UNION`       | ❌                         |
| 17 | Columnstore for aggregations on large tables            | ✅                         |
| 18 | Pre-aggregate into a reporting table                    | ✅ (trade-off: staleness)  |
| 19 | `JOIN` vs `EXISTS` vs `IN`                        | ⚠️                       |
| 20 | Avoid redundant logic                                   | ✅                         |
| 21 | Avoid `VARCHAR` and `TEXT`                          | ❌ (too broad)             |
| 22 | Avoid `MAX` and oversized lengths                     | ✅                         |
| 23 | Use `NOT NULL` where possible                         | ⚠️                       |
| 24 | Every table has a clustered primary key                 | ⚠️ (exceptions)          |
| 25 | Index frequently used foreign keys                      | ✅                         |
| 26 | Avoid over-indexing                                     | ✅                         |
| 27 | Drop unused indexes                                     | ✅                         |
| 28 | Update statistics weekly                                | ⚠️ (frequency)           |
| 29 | Reorganize / rebuild weekly                             | ⚠️ (frequency)           |
| 30 | Partition large tables, then add columnstore            | ⚠️                       |

**Corrections in one line each**

- **#7, #9:** same plan either way. Do them for clarity and safety, not speed.
- **#11:** SQL Server usually pushes filters down by itself. Pre-filtering rarely changes the plan.
- **#14:** hints override the optimizer and go stale. Fix statistics and indexes first.
- **#16:** `UNION` *is* `UNION ALL` + `DISTINCT`. Expect the same plan, not a speedup.
- **#21:** `VARCHAR` is often the *right* type. The real rules: don't store numbers or dates as text, and avoid `TEXT` (deprecated).
- **#23, #28, #29, #30:** true in spirit; see the caveats.

---

## Fetching data

### 1. Select only what you need instead of `*` ✅

**Why**

- Less data read, moved over the network and held in memory.
- Lets a **covering index** answer the query without touching the table.
- `SELECT *` breaks silently when columns are added, renamed or reordered.

```sql
-- Bad
SELECT * FROM Sales.Orders WHERE CustomerID = 4;

-- Good
SELECT OrderID, OrderDate, Sales
FROM Sales.Orders
WHERE CustomerID = 4;
```

```
 SELECT *                               SELECT OrderID, OrderDate, Sales
 index (CustomerID) -> key lookup       index (CustomerID) INCLUDE (OrderDate, Sales)
 for EVERY matching row                 -> answers from the index alone, no lookup
```

### 2. Avoid unnecessary `DISTINCT` and `ORDER BY` ✅

**Why:** both force extra work: `DISTINCT` needs a sort or hash aggregate to find duplicates, `ORDER BY` needs a sort (or an index already in that order). On big result sets that costs CPU, memory and possibly a spill to tempdb.

```sql
-- Bad: DISTINCT added "just in case" on a column that is already unique
SELECT DISTINCT CustomerID, FirstName FROM Sales.Customers;

-- Good: CustomerID is the primary key, so there are no duplicates to remove
SELECT CustomerID, FirstName FROM Sales.Customers;
```

Use them when you really need them: if the result goes to a person or a report, sort it; if duplicates are genuinely possible and unwanted, dedupe. If a `DISTINCT` is only there to hide duplicates caused by a bad join, fix the join (see #19).

### 3. Limit the rows when exploring ✅

**Why:** you only need a peek, not the full table. Less data to scan, move and render.

```sql
SELECT TOP 100 OrderID, OrderDate, Sales
FROM Sales.Orders;
```

> `TOP` without `ORDER BY` returns **arbitrary** rows. That is fine for a peek but never use it to get "the latest" or "the biggest". Pair `TOP` with `ORDER BY` for that.
> Other dialects: `LIMIT 100` (PostgreSQL, MySQL), `FETCH FIRST 100 ROWS ONLY` (Oracle, standard SQL).

---

## Filtering data

### 4. Nonclustered index on frequently used `WHERE` columns ✅

**Why:** an index turns a full scan into a seek.

```
 No index on CustomerID               Index on CustomerID
 scan all 1,000,000 rows              root -> branch -> leaf -> rows for customer 4
```

```sql
CREATE NONCLUSTERED INDEX idx_Orders_CustomerID
ON Sales.Orders (CustomerID);
```

**Caveats:** it helps when the filter is **selective** (returns a small slice). Indexing a column with 2-3 distinct values (like a yes/no flag) rarely helps. Every index slows writes (see #26).

### 5. Don't apply functions to columns in `WHERE` ✅

**Why:** an index is sorted by the *raw* column value. If you wrap the column in a function, SQL Server must compute the function for every row before it can compare, so it can't use the sort order to seek. This is called a **non-sargable** predicate.

```sql
-- Bad: function on the column -> scan
WHERE YEAR(OrderDate) = 2025

-- Good: compare the raw column to a range -> seek
WHERE OrderDate >= '2025-01-01' AND OrderDate < '2026-01-01'
```

More rewrites:

| Bad (non-sargable)                          | Good (sargable)                                                               |
| ------------------------------------------- | ----------------------------------------------------------------------------- |
| `WHERE MONTH(OrderDate) = 3`              | `WHERE OrderDate >= '2025-03-01' AND OrderDate < '2025-04-01'`              |
| `WHERE LEFT(FirstName, 1) = 'J'`          | `WHERE FirstName LIKE 'J%'`                                                 |
| `WHERE Sales * 1.1 > 500`                 | `WHERE Sales > 500 / 1.1`                                                   |
| `WHERE ISNULL(Country, '') = 'UK'`        | `WHERE Country = 'UK'`                                                      |
| `WHERE UPPER(FirstName) = 'ANA'`          | `WHERE FirstName = 'Ana'` (default collations are already case-insensitive) |
| `WHERE CAST(CustomerID AS VARCHAR) = '4'` | `WHERE CustomerID = 4`                                                      |

```
 WHERE YEAR(OrderDate) = 2025          WHERE OrderDate >= '2025-01-01' AND < '2026-01-01'

 for each row: compute YEAR(...)       index on OrderDate is sorted:
 compare -> SCAN everything            ... 2024-12-31 | 2025-01-01 ... 2025-12-31 | 2026-01-01 ...
                                                        └──── seek here, read a range ────┘
```

Use `>= start` and `< next period start` for dates. Avoid `BETWEEN '2025-01-01' AND '2025-12-31'` on `DATETIME`/`DATETIME2`: it misses everything on 12/31 after midnight.

### 6. Avoid leading wildcards ✅

**Why:** an index is sorted from the *first* character. `'John%'` says "starts with John", so SQL Server can jump to the J-o-h-n section. `'%son'` could match anywhere, so it must check every row.

```sql
-- Seek (can use an index on LastName)
WHERE LastName LIKE 'John%'

-- Scan (leading wildcard blocks the index)
WHERE LastName LIKE '%son'
WHERE LastName LIKE '%son%'
```

```
 Index (sorted):  Adams, Brown, Johnson, Johnston, Jones, ... Wilson
 'John%'  ->  jump to "Joh..." and read 2 entries
 '%son'   ->  nothing to jump to; check every entry
```

If you really need "contains" search on big tables, use **Full-Text Search** (`CONTAINS`), not `LIKE '%...%'`.

### 7. Use `IN` instead of multiple `OR` 📖

**Verdict:** this is a readability win. SQL Server treats `IN (1, 2, 3)` as `= 1 OR = 2 OR = 3` internally, so you get the **same plan**.

```sql
-- Verbose
WHERE OrderStatus = 'Shipped' OR OrderStatus = 'Delivered' OR OrderStatus = 'Returned'

-- Cleaner (same result and same plan)
WHERE OrderStatus IN ('Shipped', 'Delivered', 'Returned')
```

Checked on sample data: both return the same four orders.

The `OR` that really hurts performance is `OR` across **different columns** or inside a **join condition**. See #13.

---

## Joining data

### 8. Understand join speed; use `INNER JOIN` when possible ⚠️

**Why:** an inner join gives the optimizer the most freedom: it can reorder tables and push filters either way. Outer joins constrain it (the preserved side has to be read in full), `FULL OUTER` often needs a hash or merge join, and `CROSS JOIN` multiplies rows.

**But:** pick the join by what the result must *mean*, not by speed. Never change an outer join to inner if you need the unmatched rows.

**The classic bug: a `LEFT JOIN` silently turned into an `INNER JOIN`.**

Sample data: customers Ana, Ben, Cal, Dee. Orders: Ana (Delivered, Shipped), Ben (Delivered).

```sql
-- Filter in WHERE on the right-hand table: unmatched customers vanish
SELECT c.Name, o.OrderID
FROM Customers c
LEFT JOIN Orders o ON o.CustomerID = c.CustomerID
WHERE o.OrderStatus = 'Delivered';
```

| Name | OrderID |
| ---- | ------- |
| Ana  | 1       |
| Ben  | 3       |

Cal and Dee are gone, because their `OrderStatus` is `NULL` and `NULL = 'Delivered'` is not true. It behaves like an inner join.

```sql
-- Put the condition in ON to keep the LEFT JOIN behaviour
SELECT c.Name, o.OrderID
FROM Customers c
LEFT JOIN Orders o ON o.CustomerID = c.CustomerID
                  AND o.OrderStatus = 'Delivered';
```

| Name | OrderID |
| ---- | ------- |
| Ana  | 1       |
| Ben  | 3       |
| Cal  | NULL    |
| Dee  | NULL    |

If you *meant* inner semantics, write `INNER JOIN` so the optimizer and the next reader both know.

### 9. Use explicit (ANSI) joins instead of implicit joins 📖

**Verdict:** same plan. This is about correctness and readability.

```sql
-- Implicit (old style): the join condition hides in WHERE
SELECT c.FirstName, o.OrderID
FROM Sales.Customers c, Sales.Orders o
WHERE c.CustomerID = o.CustomerID;

-- Explicit (ANSI): the join is stated where the tables are
SELECT c.FirstName, o.OrderID
FROM Sales.Customers c
INNER JOIN Sales.Orders o ON c.CustomerID = o.CustomerID;
```

**Why it's safer:** forget the `WHERE` in the implicit version and you silently get a **cross join** (4 customers × 4 orders = 16 rows in the sample data). With `INNER JOIN` a missing `ON` is a syntax error. Explicit syntax also separates join logic from filter logic, and is the only way to write outer joins in modern T-SQL (the old `*=` operators were removed).

### 10. Index the columns used in `ON` ✅

**Why:** for each row from one table, the engine has to find the matching rows in the other. Without an index on the join column that is a scan per row (or a hash build over everything).

- **Primary keys** are indexed automatically.
- **Foreign keys are not.** SQL Server does *not* create an index on the child column.

```sql
CREATE NONCLUSTERED INDEX idx_Orders_CustomerID
ON Sales.Orders (CustomerID);          -- speeds Customers -> Orders joins
```

### 11. Filter before joining ⚠️

**The idea:** reduce rows first, so the join handles less data.

```sql
-- Join first, filter after (reads naturally)
SELECT c.FirstName, o.OrderID, o.Sales
FROM Sales.Customers c
JOIN Sales.Orders o ON o.CustomerID = c.CustomerID
WHERE o.OrderStatus = 'Delivered';

-- Filter in a CTE first, then join
WITH DeliveredOrders AS (
    SELECT OrderID, CustomerID, Sales
    FROM Sales.Orders
    WHERE OrderStatus = 'Delivered'
)
SELECT c.FirstName, d.OrderID, d.Sales
FROM Sales.Customers c
JOIN DeliveredOrders d ON d.CustomerID = c.CustomerID;
```

**Reality check:** for an `INNER JOIN` with a simple filter, SQL Server's optimizer **pushes the filter down on its own**. A CTE is not a temporary result either (it's expanded into the query), so both versions normally produce the **same plan**. It helps in cases the optimizer can't see through (complex expressions, results after an aggregate), and it can make a big query easier to read. Compare the plans before rewriting. That is exactly what the golden rule says.

```
 Optimizer's view of both versions:

 Customers ──┐
             ├─ JOIN ── result          Orders ── Filter(Delivered) ──┐
 Orders ─────┘                                                        ├─ JOIN
        (filter pushed down to Orders)                    Customers ──┘
```

### 12. Aggregate before joining ⚠️

**The idea:** shrink a many-row table to one row per key *before* it meets the next table.

```sql
-- Aggregate first: the join sees 1 row per customer, not 1 per order
SELECT c.FirstName, o.TotalSales
FROM Sales.Customers c
JOIN (
    SELECT CustomerID, SUM(Sales) AS TotalSales
    FROM Sales.Orders
    GROUP BY CustomerID
) o ON o.CustomerID = c.CustomerID;
```

```
 Join then aggregate:           Aggregate then join:
 1,000,000 orders               1,000,000 orders
   ↓ join to Customers            ↓ GROUP BY CustomerID
 1,000,000 joined rows          10,000 rows
   ↓ GROUP BY                     ↓ join to Customers
 10,000 results                 10,000 results
```

The optimizer sometimes does this itself, so measure. For small tables it doesn't matter.

**The correctness bonus (more important than speed):** joining a table to a one-to-many table *before* summing **repeats rows** and inflates totals.

Sample data: order 1 (sales 100) has 3 items, order 2 (sales 50) has 1, Ana owns both.

```sql
-- Wrong: Sales repeated once per item
SELECT c.Name, SUM(o.Sales) AS TotalSales
FROM Customers c
JOIN Orders o      ON o.CustomerID = c.CustomerID
JOIN OrderItems i  ON i.OrderID    = o.OrderID
GROUP BY c.Name;
```

| Name | TotalSales                  |
| ---- | --------------------------- |
| Ana  | **350** (100×3 + 50) |
| Ben  | 200                         |

```sql
-- Right: aggregate orders on their own, then join
SELECT c.Name, o.TotalSales
FROM Customers c
JOIN (SELECT CustomerID, SUM(Sales) AS TotalSales FROM Orders GROUP BY CustomerID) o
  ON o.CustomerID = c.CustomerID;
```

| Name | TotalSales    |
| ---- | ------------- |
| Ana  | **150** |
| Ben  | 200           |

### 13. Use `UNION` instead of `OR` in joins ⚠️

**Why:** an `OR` between conditions in an `ON` clause (`a.Email = b.Email OR a.Phone = b.Phone`) can't be satisfied by one index seek or one hash/merge key, so SQL Server often falls back to a **nested loop with scans**. Splitting it into two joins, each with a simple equality, lets each branch use its own index.

```sql
-- Slow pattern
SELECT a.AID, b.BID
FROM A a
JOIN B b ON a.Email = b.Email OR a.Phone = b.Phone;

-- Rewrite
SELECT a.AID, b.BID FROM A a JOIN B b ON a.Email = b.Email
UNION
SELECT a.AID, b.BID FROM A a JOIN B b ON a.Phone = b.Phone;
```

```
 ON x OR y                         x branch ──┐
 one join, can't seek on either             ├─ UNION ── result
                                   y branch ──┘
                                   (each branch can use its own index)
```

**Watch the overlap.** A pair that matches on *both* email and phone appears in both branches. Checked with sample data (A1/B10 match on both):

| Version                                                            | Result                                             |
| ------------------------------------------------------------------ | -------------------------------------------------- |
| `OR` join                                                        | (1,10) (2,11) (3,12)                               |
| `UNION`                                                          | (1,10) (2,11) (3,12) ✅ same                       |
| `UNION ALL`                                                      | (1,10) **(1,10)** (2,11) (3,12) ❌ duplicate |
| `UNION ALL` with `AND a.Email <> b.Email` in the second branch | (1,10) (2,11) (3,12) ✅ same, no sort needed       |

So use `UNION` (safe), or `UNION ALL` plus an exclusion condition (faster, since it skips the duplicate-removal step). `UNION ALL` alone gives wrong answers when branches overlap.

> Note that `OR` in a `WHERE` on one table is a different story: the optimizer can often use two index seeks and merge them. Rewrite only when the plan shows a scan.

### 14. Check for nested loops, and use hints ⚠️

SQL Server has three physical join algorithms:

| Algorithm              | How it works                                                                | Good when                                                     |
| ---------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **Nested Loops** | For each row of the outer (small) input, look up matches in the inner input | Outer input is small and the inner side has an index          |
| **Hash Match**   | Build a hash table from the smaller input, probe it with the other          | Large, unsorted, unindexed inputs; needs memory               |
| **Merge Join**   | Walk two inputs that are **already sorted** on the join key in step   | Both inputs are big and sorted (e.g. both indexed on the key) |

```
 Nested Loops               Hash Match                 Merge Join
 for each outer row:        1) hash small input        both sorted by key:
   look up inner            2) probe with big input    ▶ 1 1 2 3 5
                                                       ▶ 1 2 2 3 4   walk together
 1,000,000 × lookups?
 -> very slow if both big
```

**What to look for:** a nested loop where both inputs are large, or the same inner lookup running millions of times (check the "Number of Executions" in the plan).

**Hints:** you can force a choice:

```sql
SELECT c.FirstName, o.Sales
FROM Sales.Customers c
INNER HASH JOIN Sales.Orders o ON o.CustomerID = c.CustomerID;   -- join hint

-- or for the whole query
SELECT ... OPTION (HASH JOIN);
```

**Use them last, not first.** A hint overrides the optimizer *forever*, even after the data grows or changes and the hinted choice becomes the wrong one. Nested loops on big inputs usually appears because the optimizer **guessed the wrong row counts**. Try first:

1. `UPDATE STATISTICS` (stale stats are the usual culprit).
2. Add or fix an index on the join columns (#10).
3. Look at estimated vs actual rows in the plan.
4. Only then consider a hint, and document why.

### 15. Use `UNION ALL` instead of `UNION` if duplicates are acceptable ✅

**Why:** `UNION` has to find and remove duplicates (sort or hash all rows). `UNION ALL` just appends.

```sql
-- Checked on T1 = {1,2,2,3} and T2 = {2,3,3,4}
SELECT v FROM T1 UNION     SELECT v FROM T2;   -- 1, 2, 3, 4          (4 rows)
SELECT v FROM T1 UNION ALL SELECT v FROM T2;   -- 1,2,2,2,3,3,3,4     (8 rows)
```

Typical use: combining tables that **can't overlap** by design (e.g. `Orders_2024` + `Orders_2025`), so you pay for no dedupe.

### 16. `UNION ALL` + `DISTINCT` instead of `UNION` ❌

**Verdict:** the claim doesn't hold. `UNION` is *defined* as `UNION ALL` followed by `DISTINCT`, so the two forms are logically identical:

```sql
-- Same result (checked: 1, 2, 3, 4)
SELECT v FROM T1 UNION SELECT v FROM T2;

SELECT DISTINCT v
FROM (SELECT v FROM T1 UNION ALL SELECT v FROM T2) t;
```

I'd expect SQL Server to compile both to the same plan (a concatenation followed by one distinct step), so rewriting gains nothing. I can't run SQL Server here, so confirm in your own execution plans. The practical rule is just the pair:

- Duplicates are fine, or impossible by design -> `UNION ALL` (#15).
- Duplicates must go -> `UNION`. It says what you mean.

---

## Aggregating data

### 17. Use a columnstore index for aggregations on large tables ✅

**Why:** aggregations read a few columns across millions of rows. Columnstore stores each column together and compressed, so `SUM(Sales)` reads only the `Sales` data, and processes it in batches.

```
 Rowstore: reads every column of every row     Columnstore: reads just the Sales column
 [ID|Name|Country|Sales] [ID|Name|...] ...     [100, 250, 80, 300, 90 ...] compressed
```

```sql
CREATE CLUSTERED COLUMNSTORE INDEX idx_FactSales_CS
ON Sales.FactSales;

SELECT ProductID, SUM(Sales) AS TotalSales
FROM Sales.FactSales
GROUP BY ProductID;
```

Best for **analytics (OLAP)** on large, mostly-appended tables. Not for tiny tables or heavy single-row updates. See the `sql-indexes.md` notes on rowstore vs columnstore.

### 18. Pre-aggregate data and store it for reporting ✅

**Why:** if a dashboard recalculates the same `GROUP BY` over millions of rows every time anyone opens it, compute it once and store the result.

```sql
-- Build a summary table once (nightly, or after each load)
SELECT
    YEAR(OrderDate)  AS OrderYear,
    MONTH(OrderDate) AS OrderMonth,
    ProductID,
    SUM(Sales)       AS TotalSales,
    COUNT(*)         AS OrderCount
INTO Sales.MonthlySales
FROM Sales.Orders
GROUP BY YEAR(OrderDate), MONTH(OrderDate), ProductID;

-- Reports read the small table
SELECT OrderYear, SUM(TotalSales) FROM Sales.MonthlySales GROUP BY OrderYear;
```

```
 Raw orders (50,000,000 rows) ──► nightly job ──► MonthlySales (~5,000 rows) ──► dashboards
```

**Trade-offs**

- The summary can be **stale** until refreshed. Decide how fresh the report must be.
- You must maintain the refresh job and keep logic in one place.
- Alternatives: an **indexed view** (SQL Server keeps it up to date automatically, but it has restrictions: `SCHEMABINDING`, `COUNT_BIG(*)`, no outer joins...) or a scheduled `TRUNCATE` + `INSERT`.

---

## Subqueries

### 19. `JOIN` vs `EXISTS` vs `IN` ⚠️

There is no universal winner. SQL Server often turns `IN` and `EXISTS` into the same **semi join**, so measure. What differs reliably is **what each one returns** and how it behaves with `NULL`.

Sample data: customers Ana(1), Ben(2), Cal(3), Dee(4). `Orders.CustomerID`: 1, 1, 2, **NULL**.

**"Customers who have orders"**

| Method                    | Result                  | Note                                           |
| ------------------------- | ----------------------- | ---------------------------------------------- |
| `JOIN`                  | Ana, **Ana**, Ben | Repeats customers who have several orders      |
| `IN (SELECT ...)`       | Ana, Ben                | One row per customer                           |
| `EXISTS (SELECT 1 ...)` | Ana, Ben                | One row per customer, stops at the first match |

```sql
-- JOIN: use when you need columns from the other table (and accept repeats / aggregate)
SELECT c.Name, o.OrderID FROM Customers c JOIN Orders o ON o.CustomerID = c.CustomerID;

-- IN
SELECT Name FROM Customers WHERE CustomerID IN (SELECT CustomerID FROM Orders);

-- EXISTS: only checking that a match exists
SELECT Name FROM Customers c
WHERE EXISTS (SELECT 1 FROM Orders o WHERE o.CustomerID = c.CustomerID);
```

**"Customers with NO orders": the `NOT IN` trap**

```sql
-- Returns NOTHING (verified)
SELECT Name FROM Customers
WHERE CustomerID NOT IN (SELECT CustomerID FROM Orders);

-- Returns Cal, Dee (verified)
SELECT Name FROM Customers c
WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.CustomerID = c.CustomerID);
```

One `NULL` in the subquery makes `NOT IN` return no rows at all, because `x NOT IN (1, 2, NULL)` can never be true. **Use `NOT EXISTS`** (or a `LEFT JOIN ... WHERE o.CustomerID IS NULL`).

| Need                         | Use                                                    |
| ---------------------------- | ------------------------------------------------------ |
| Existence check              | `EXISTS`                                             |
| Columns from the other table | `JOIN`                                               |
| Short fixed or small list    | `IN`                                                 |
| "Has no match"               | `NOT EXISTS` (never `NOT IN` on a nullable column) |

### 20. Avoid redundant logic in queries ✅

**Why:** repeating the same work (the same table scanned several times, the same calculation duplicated, a correlated subquery that runs once per row) multiplies cost and makes bugs likelier when only one copy is updated.

```sql
-- Bad: three scans of Orders
SELECT
    (SELECT COUNT(*) FROM Sales.Orders WHERE OrderStatus = 'Delivered') AS Delivered,
    (SELECT COUNT(*) FROM Sales.Orders WHERE OrderStatus = 'Shipped')   AS Shipped,
    (SELECT COUNT(*) FROM Sales.Orders)                                 AS Total;

-- Good: one scan, conditional aggregation
SELECT
    COUNT(CASE WHEN OrderStatus = 'Delivered' THEN 1 END) AS Delivered,
    COUNT(CASE WHEN OrderStatus = 'Shipped'   THEN 1 END) AS Shipped,
    COUNT(*)                                              AS Total
FROM Sales.Orders;
```

More patterns:

| Redundant                                               | Replace with                                       |
| ------------------------------------------------------- | -------------------------------------------------- |
| Correlated subquery per row for a running total or rank | Window function (`SUM() OVER`, `ROW_NUMBER()`) |
| Same subquery pasted 3 times                            | CTE, or a temp table if it is expensive and reused |
| Self-join to compare with the previous row              | `LAG` / `LEAD`                                 |

> A CTE referenced twice is **evaluated twice**; it isn't cached. If an expensive result is reused many times, store it in a temp table (`#t`).

---

## Creating tables

### 21. Avoid `VARCHAR` and `TEXT` when possible ❌ (too broad)

**What's right in it:** don't use text types where a *better* type exists, and never use `TEXT`.

**What's wrong:** `VARCHAR` is not a problem in itself. For genuinely variable text (names, addresses) it's usually the best choice, since it stores only the characters used (+2 bytes).

| Situation                                        | Use                                     | Not                                               |
| ------------------------------------------------ | --------------------------------------- | ------------------------------------------------- |
| Number                                           | `INT`, `BIGINT`, `DECIMAL`        | `VARCHAR`                                       |
| Date                                             | `DATE`, `DATETIME2`                 | `VARCHAR`                                       |
| Yes/No                                           | `BIT`                                 | `VARCHAR('Y')`                                  |
| Fixed-length code (country `UK`, state `CA`) | `CHAR(2)`                             | `VARCHAR(50)`                                   |
| Variable text, ASCII only                        | `VARCHAR(n)`                          | `NVARCHAR` if you don't need Unicode            |
| Variable text, any language                      | `NVARCHAR(n)` (2 bytes per character) |                                                   |
| Long text                                        | `VARCHAR(MAX)` / `NVARCHAR(MAX)`    | **`TEXT` / `NTEXT`: deprecated, avoid** |

**Why**

| Value            | As text                        | As proper type                  |
| ---------------- | ------------------------------ | ------------------------------- |
| `'2025-01-15'` | `VARCHAR(10)` = 12 bytes     | `DATE` = **3 bytes**    |
| `1234567`      | `VARCHAR(7)` = 9 bytes       | `INT` = **4 bytes**     |
| `'UK'`         | `VARCHAR(2)` = up to 4 bytes | `CHAR(2)` = **2 bytes** |

Beyond size:

- Text dates allow garbage (`'2025-13-45'`) and sort alphabetically, not chronologically (`'9/1'` after `'10/1'` as text).
- Comparing a text column with a number forces an **implicit conversion** that can block index use.
- Smaller rows mean more rows per page, so fewer pages read and more of the table fits in memory.

```sql
-- Bad
CREATE TABLE Sales.CustomersBad (
    CustomerID  VARCHAR(50),
    BirthDate   VARCHAR(50),
    Country     VARCHAR(MAX),
    Notes       TEXT
);

-- Good
CREATE TABLE Sales.CustomersGood (
    CustomerID  INT           NOT NULL PRIMARY KEY,
    FirstName   NVARCHAR(50)  NOT NULL,
    BirthDate   DATE          NULL,
    CountryCode CHAR(2)       NOT NULL,
    Notes       NVARCHAR(500) NULL
);
```

### 22. Avoid `MAX` and unnecessarily large lengths ✅

**Why**

- **`MAX` columns can't be index keys**, and large values may be stored off-row, which is slower to read.
- SQL Server plans memory for sorts and hashes by **guessing a variable-length column is about half its declared size**. `VARCHAR(8000)` holding short strings still reserves roughly 4,000 bytes per row in the estimate, producing oversized memory grants (queries wait for memory) or spills.
- Index key size is limited (900 bytes clustered, 1,700 bytes nonclustered); huge declared lengths can hit it.
- The declared length documents what the data really is.

```sql
-- Bad
Email    NVARCHAR(MAX)
Country  VARCHAR(1000)

-- Good
Email    NVARCHAR(254)       -- max length of an email address
Country  CHAR(2)             -- ISO code
```

Use `MAX` only for genuinely large values (documents, JSON blobs).

### 23. Use `NOT NULL` where possible ⚠️

**Real benefits**

- **Data quality:** the database refuses missing values, so you don't rely on every application remembering.
- **Simpler logic and fewer bugs:** `NULL` makes comparisons three-valued (`<>`, `NOT IN` and `COUNT(col)` behave in surprising ways; see #19).
- A little help for the optimizer: it can skip `NULL` handling and, in some cases, simplify joins and anti-joins.

**Realistic expectation:** the pure speed benefit is usually small. Don't expect big gains, and don't force `NOT NULL` on a column that is legitimately optional (a second phone number, an end date for an ongoing contract). Use it where "no value" has no valid meaning.

```sql
ALTER TABLE Sales.Customers
ALTER COLUMN FirstName NVARCHAR(50) NOT NULL;   -- fails if NULLs already exist; clean them first
```

### 24. Ensure all tables have a clustered primary key ⚠️

**Why:** it gives the table a sorted structure (fast seeks and range scans), uniquely identifies every row, and makes the table easier to maintain and replicate. A heap has none of that (see `sql-indexes.md`).

```sql
CREATE TABLE Sales.Orders (
    OrderID   INT IDENTITY(1,1) NOT NULL,
    OrderDate DATE NOT NULL,
    Sales     INT NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID)
);
```

**A good clustered key is narrow, unique, static and ever-increasing.** `INT IDENTITY` fits. A random `NEWID()` GUID as the clustered key inserts into random pages, causing **page splits and fragmentation** (see `sql-index-maintenance.md`). If you need GUIDs, use `NEWSEQUENTIALID()` or keep the GUID in a unique nonclustered index.

**Valid exceptions**

- **Staging tables** loaded and wiped: a heap loads fastest.
- **Data-warehouse fact tables** with a *clustered columnstore* index, where a primary key is often omitted.

### 25. Create nonclustered indexes for frequently used foreign keys ✅

**Why:** SQL Server does **not** index foreign key columns automatically. Without an index:

- Joins from parent to child scan the child table (see #10).
- Deleting or updating a parent row makes SQL Server scan the child table to check for dependents, which can also hold **locks** longer and block other sessions.

```sql
ALTER TABLE Sales.Orders
ADD CONSTRAINT FK_Orders_Customers
    FOREIGN KEY (CustomerID) REFERENCES Sales.Customers (CustomerID);

CREATE NONCLUSTERED INDEX idx_Orders_CustomerID
ON Sales.Orders (CustomerID);          -- the FK does not create this for you
```

"Frequently used" is a fair filter: a foreign key that is never joined or filtered on may not be worth the write cost.

---

## Indexing

(More detail in `sql-indexes.md` and `sql-index-maintenance.md`.)

### 26. Avoid over-indexing ✅

**Why:** every index must be updated on every `INSERT`, `UPDATE` and `DELETE` touching its columns, and takes disk and memory. Ten indexes on a busy table means ten extra writes per row.

```
 INSERT 1 row into a table with 1 clustered + 8 nonclustered indexes
   ──► 1 table write + 8 index writes  (+ log records for all of them)
```

Index for the queries you actually run. Merge overlapping indexes and check the missing-index and duplicate-index reports.

### 27. Drop unused indexes ✅

**Why:** an index nobody reads still costs writes and space (#26).

```sql
SELECT OBJECT_NAME(i.object_id) AS TableName, i.name AS IndexName,
       s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s
  ON s.object_id = i.object_id AND s.index_id = i.index_id AND s.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND i.type_desc = 'NONCLUSTERED'
  AND ISNULL(s.user_seeks + s.user_scans + s.user_lookups, 0) = 0;
```

The counters reset on restart, so confirm over a full business cycle first. Don't drop indexes that enforce a primary key or unique constraint. A safer first step is `ALTER INDEX ... DISABLE`.

### 28. Update statistics (weekly) ⚠️

**Why:** the optimizer picks plans from statistics about your data. Stale statistics lead to wrong row-count guesses, and therefore to bad plans (the nested-loops-on-big-tables problem in #14).

```sql
UPDATE STATISTICS Sales.Orders;          -- one table
EXEC sp_updatestats;                     -- whole database (only changed stats)
```

**Weekly is a starting point, not a rule:**

- Databases have **auto-update statistics** on by default.
- A rule of thumb is: update after significant data change, not by calendar. A heavily loaded table may need it daily; a static reference table almost never.
- `ALTER INDEX ... REBUILD` already refreshes that index's statistics; `REORGANIZE` does not.

### 29. Reorganize and rebuild indexes (weekly) ⚠️

**Why:** page splits, deletes and updates leave pages half-empty or out of order, so scans read more pages.

```sql
ALTER INDEX idx_Orders_CustomerID ON Sales.Orders REORGANIZE;   -- light, 5-30% fragmentation
ALTER INDEX idx_Orders_CustomerID ON Sales.Orders REBUILD;      -- heavy, >30% fragmentation
```

**Make it threshold-based, not blind:** check `sys.dm_db_index_physical_stats`, skip small indexes (under about 1,000 pages) and only touch fragmented ones. On SSDs, logical fragmentation costs far less than on spinning disks; low page density and stale statistics still matter. Measure whether your rebuilds actually speed up queries before running a heavy nightly job.

### 30. Partition large tables, then apply a columnstore index ⚠️

**Why:** partitioning splits a huge table (usually by date) into chunks. Two payoffs:

1. **Query speed via partition elimination:** a query filtered on the partition key reads only the matching partitions.
2. **Manageability:** archive or load a whole partition instantly with `SWITCH`, and rebuild or back up one partition at a time.

Add **clustered columnstore** on top and you get compression and fast scans inside each partition. This is the standard data-warehouse fact table pattern.

```
 Fact table partitioned by month, columnstore in each partition

 Jan │ Feb │ Mar │ Apr │ ...
 ███ │ ███ │ ███ │ ███ │      WHERE OrderDate in March  ──►  read only the Mar partition
```

**Caveats**

- Partitioning **by itself doesn't speed queries up**. Queries that don't filter on the partition key still touch every partition, and a bad design can make them slower.
- It's worth it for **very large** tables (tens or hundreds of millions of rows and up), not for a few thousand.
- A unique index must include the partition key, and thousands of partitions bring their own overhead.

See `sql-partitioning.md` for the build steps.

---

## Cheat sheet

| Area                      | Do                                                                                | Don't                                                      |
| ------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| **Columns**         | List the columns you need                                                         | `SELECT *`                                               |
| **Result**          | `DISTINCT` / `ORDER BY` only when needed                                      | Add them "just in case"                                    |
| **Filters**         | Compare the raw column to a value or range                                        | Wrap the column in `YEAR()`, `LEFT()`, `ISNULL()`... |
| **LIKE**            | `'abc%'`                                                                        | `'%abc'` or `'%abc%'`                                  |
| **Joins**           | Explicit `INNER JOIN ... ON`; index the join columns and FKs                    | Comma joins; `OR` inside `ON`                          |
| **LEFT JOIN**       | Put right-table conditions in `ON`                                              | Filter the right table in `WHERE` (turns it inner)       |
| **Combining**       | `UNION ALL` if duplicates are fine or impossible                                | `UNION` by habit                                         |
| **"Doesn't exist"** | `NOT EXISTS`                                                                    | `NOT IN` on a nullable column                            |
| **Aggregates**      | Aggregate before a one-to-many join; columnstore for big scans                    | Join, then `SUM` over repeated rows                      |
| **Types**           | Right type and size (`INT`, `DATE`, `CHAR(2)`, `VARCHAR(n)`)              | Dates/numbers as text; `TEXT`; oversized `MAX`         |
| **Tables**          | Clustered PK; index frequently used FKs; `NOT NULL` where "no value" is invalid | Random-GUID clustered keys                                 |
| **Indexes**         | Index real queries; drop unused; keep stats fresh; rebuild by threshold           | Over-index; blind weekly rebuild; hints as a first resort  |
| **Huge tables**     | Partition by date + columnstore                                                   | Partition small tables                                     |
| **Always**          | Check the plan and `STATISTICS IO`                                              | Trust a rule without measuring                             |

```
 Optimization order that usually pays off most

 1. Right query shape (columns, sargable filters, correct joins)
 2. Right indexes (and no useless ones)
 3. Fresh statistics
 4. Right data types and table design
 5. Heavy tools (pre-aggregation, columnstore, partitioning)
 6. Hints: last resort
```
