
# Subquery vs CTE vs View vs CTAS vs Temp Table

All five let you **reuse the result of a query as if it were a table**. They differ in **how long they live, whether they store data, who can use them, and how fresh the data is**. This guide explains each one, compares them side by side, and shows when to pick which.

Examples use **T-SQL (SQL Server)**. See [Dialect Differences](#dialect-differences) for PostgreSQL, MySQL and Oracle.

---

## Table of Contents

- [The Short Version](#the-short-version)
- [The Big Picture](#the-big-picture)
- [Sample Data](#sample-data)
- [1. Subquery](#1-subquery)
- [2. CTE](#2-cte-common-table-expression)
- [3. View](#3-view)
- [4. CTAS](#4-ctas-create-table-as-select)
- [5. Temp Table](#5-temp-table)
- [The Same Task Five Ways](#the-same-task-five-ways)
- [Fresh Data vs Snapshot](#fresh-data-vs-snapshot)
- [Performance Notes](#performance-notes)
- [Decision Guide](#decision-guide)
- [Dialect Differences](#dialect-differences)
- [Common Mistakes](#common-mistakes)
- [Cheat Sheet](#cheat-sheet)

---

## The Short Version

|                      | One-liner                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------- |
| **Subquery**   | A query**inside** another query. Exists only while that query runs                                |
| **CTE**        | A**named** subquery written at the top with `WITH`. Exists for **one statement**          |
| **View**       | A**saved query** stored in the database. Shows live data, stores no data                          |
| **CTAS**       | **Creates a real table** from a query's result. A **snapshot** that stays until you drop it |
| **Temp table** | A real table in`tempdb` that **disappears automatically** when your session ends                |

The key split:

- **Don't store data** (just a query): subquery, CTE, view. Always current, re-run every time.
- **Store data** (a physical copy): CTAS, temp table. Fast to re-read, but a **snapshot** that goes stale.

---

## The Big Picture

```
                         Stores data?
                    No ──────────────────── Yes
                     │                       │
      ┌──────────────┼──────────────┐        ├──────────────┐
  Subquery          CTE           View     Temp table      CTAS
  (inline)       (named, one    (saved,    (temporary,    (permanent
                  statement)    permanent)  in tempdb)      table)
```

|                                              | Subquery                          | CTE                       | View                                      | Temp table                              | CTAS table                                                |
| -------------------------------------------- | --------------------------------- | ------------------------- | ----------------------------------------- | --------------------------------------- | --------------------------------------------------------- |
| **Stores data?**                       | No                                | No                        | No                                        | **Yes** (tempdb)                  | **Yes** (disk)                                      |
| **Exists until**                       | Statement ends                    | Statement ends            | `DROP VIEW`                             | Session ends (or dropped)               | `DROP TABLE`                                            |
| **Data freshness**                     | Live                              | Live                      | Live                                      | **Snapshot**                      | **Snapshot**                                        |
| **Visible to**                         | That query                        | That statement            | **Everyone** with permission        | Your session only (`#`)               | **Everyone** with permission                        |
| **Reusable in later statements**       | No                                | No                        | **Yes**                             | **Yes** (in the session)          | **Yes**                                             |
| **Can be indexed**                     | No                                | No                        | Only as an indexed view                   | **Yes**                           | **Yes**                                             |
| **Has statistics (for the optimiser)** | n/a                               | n/a                       | n/a                                       | **Yes**                           | **Yes**                                             |
| **Needs create/drop permissions**      | No                                | No                        | Yes (create view)                         | Basic (temp objects)                    | Yes (create table)                                        |
| **Recursion**                          | No                                | **Yes**             | No                                        | No                                      | No                                                        |
| **Best for**                           | Quick filters and one-off lookups | Readable multi-step logic | Shared, reusable definitions and security | Reusing a heavy result within a process | Persisting results (staging, snapshots, reporting tables) |

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
(5, 'Anna',   'Adams');          -- no orders

CREATE TABLE Sales.Orders (
    OrderID    INT PRIMARY KEY,
    ProductID  INT,
    CustomerID INT,
    OrderDate  DATE,
    Sales      INT
);

INSERT INTO Sales.Orders VALUES
(1,  101, 2, '2025-01-01', 10),
(2,  102, 3, '2025-01-05', 15),
(3,  101, 1, '2025-01-10', 20),
(4,  105, 1, '2025-01-20', 60),
(5,  104, 2, '2025-02-01', 25),
(6,  104, 3, '2025-02-05', 50),
(7,  102, 1, '2025-02-10', 30),
(8,  101, 3, '2025-02-15', 90),
(9,  101, 1, '2025-03-01', 20),
(10, 102, 2, '2025-03-10', 60),
(11, 103, 4, '2025-03-20', 40);
```

Total sales per customer: Jossef 130, Kevin 95, Mary 155, Mark 40, Anna none.

---

# 1. Subquery

A **query nested inside another query**. It runs as part of the outer query and disappears when the outer query finishes.

### Where subqueries can go

| Location                     | Example                                                   | Notes                                                    |
| ---------------------------- | --------------------------------------------------------- | -------------------------------------------------------- |
| `FROM` (derived table)     | `FROM (SELECT ...) AS t`                                | Acts like a table.**Needs an alias** in SQL Server |
| `WHERE` with `IN`        | `WHERE CustomerID IN (SELECT ...)`                      | Matches against a list                                   |
| `WHERE` with `EXISTS`    | `WHERE EXISTS (SELECT 1 FROM ... WHERE ...)`            | True/false check,`NULL`-safe                           |
| `WHERE` with a comparison  | `WHERE Sales > (SELECT AVG(Sales) FROM ...)`            | Subquery must return**one value**                  |
| `SELECT` (scalar subquery) | `SELECT ..., (SELECT MAX(Sales) FROM ...) AS max_sales` | Must return**one row, one column**                 |
| `JOIN`                     | `JOIN (SELECT ...) AS t ON ...`                         | Same as`FROM`                                          |

### Non-correlated vs correlated

```sql
-- non-correlated: runs on its own, independent of the outer query
SELECT *
FROM Sales.Orders
WHERE Sales > (SELECT AVG(Sales) FROM Sales.Orders);

-- correlated: refers to the outer row, so it depends on each outer row
SELECT c.CustomerID, c.FirstName
FROM Sales.Customers AS c
WHERE EXISTS (
    SELECT 1
    FROM Sales.Orders AS o
    WHERE o.CustomerID = c.CustomerID       -- uses the outer table
);
```

|                        | Non-correlated | Correlated                                                     |
| ---------------------- | -------------- | -------------------------------------------------------------- |
| Depends on outer query | No             | **Yes**                                                  |
| Can run on its own     | Yes            | No                                                             |
| Conceptually runs      | Once           | Once per outer row (the optimiser often rewrites it as a join) |

### Use cases

- **Filter against a computed value:** rows above the average.
- **Existence checks:** customers who have (or have no) orders, with `EXISTS` / `NOT EXISTS`.
- **A quick one-off derived table** in `FROM`.
- **A single computed value** next to every row (scalar subquery).

### Pros and cons

| Pros                                                | Cons                                                                                           |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| No setup, no permissions, no cleanup                | Gets unreadable when nested several levels deep                                                |
| Natural for`IN` / `EXISTS` / scalar comparisons | Can't be reused. You must copy it each time you need it                                        |
| Correlated form can express "per row" logic         | Can't be recursive                                                                             |
|                                                     | A scalar subquery that returns more than one row fails:`Subquery returned more than 1 value` |

> **`NOT IN` + `NULL` trap:** if the subquery returns even one `NULL`, `NOT IN` returns **no rows**. Use `NOT EXISTS` instead.

---

# 2. CTE (Common Table Expression)

A **named, temporary result set** defined with `WITH` at the top of a statement. It's a subquery with a name, written first and used like a table.

```sql
WITH CTE_total_sales AS (
    SELECT CustomerID, SUM(Sales) AS total_sales
    FROM Sales.Orders
    GROUP BY CustomerID
)
SELECT *
FROM CTE_total_sales
WHERE total_sales > 100;
```

### Types

| Type                 | Meaning                                                                             |
| -------------------- | ----------------------------------------------------------------------------------- |
| **Standalone** | Reads from real tables only                                                         |
| **Nested**     | Builds on an earlier CTE (`WITH a AS (...), b AS (SELECT ... FROM a)`)            |
| **Recursive**  | Refers to itself, repeating until no new rows (hierarchies, number and date series) |

### Use cases

- **Breaking a complex query into named steps** that read top to bottom.
- **Using the same intermediate result more than once** in one statement.
- **Filtering on a window function:** rank in the CTE, filter in the main query.
- **Recursion:** org charts, category trees, generating number or date series.
- **De-duplicating:** `ROW_NUMBER()` in a CTE, then `DELETE ... WHERE rn > 1`.

### Pros and cons

| Pros                                                      | Cons                                                                     |
| --------------------------------------------------------- | ------------------------------------------------------------------------ |
| Much more readable than nested subqueries                 | Lives for**one statement only**                                    |
| Can be referenced several times                           | **Not stored or cached.** SQL Server re-runs it for each reference |
| Supports recursion                                        | Can't be indexed                                                         |
| Can be the target of`UPDATE` / `DELETE` in SQL Server | No`ORDER BY` inside (without `TOP`)                                  |
|                                                           | A statement before`WITH` needs a semicolon                             |

> A CTE is **a readability tool, not a performance tool**. For the optimiser, a CTE and the equivalent subquery are usually the same thing.

---

# 3. View

A **saved query stored in the database**. It's a virtual table: the definition is stored, the data is not. Each time you query it, the underlying query runs and returns current data.

```sql
CREATE VIEW Sales.V_Customer_Sales AS
SELECT CustomerID, SUM(Sales) AS total_sales
FROM Sales.Orders
GROUP BY CustomerID;
GO

SELECT * FROM Sales.V_Customer_Sales WHERE total_sales > 100;
```

### Use cases

- **Hide complexity:** wrap a multi-table join so users query one object.
- **Data security:** expose only certain columns or rows (grant on the view, deny on the tables).
- **Consistency:** define a business rule (net sales, active customer) **once** so every report uses the same logic.
- **Abstraction:** keep consumers working when the underlying tables change.
- **Data marts:** present a warehouse as subject-focused slices.
- **Multiple languages:** the same data with translated column names.

### Pros and cons

| Pros                                                     | Cons                                                      |
| -------------------------------------------------------- | --------------------------------------------------------- |
| Shared by everyone, reusable across queries and sessions | **No speed benefit.** The query runs every time     |
| Always current                                           | Needs create/alter permissions and a name in the schema   |
| Good for security and consistency                        | Stacked views (views on views) get hard to debug and slow |
| Hides table changes from consumers                       | `SELECT *` freezes columns, and no `ORDER BY` inside  |
|                                                          | Complex views (joins, aggregates) are read-only           |

> An **indexed (materialised) view** is the exception: it physically stores the results and keeps them up to date, at the cost of slower writes and many restrictions. Without that, a view is just a stored query.

---

# 4. CTAS (Create Table As Select)

**CTAS creates a real, permanent table from the result of a query.** It stores the data physically, as a **snapshot** at the moment you run it. The table stays until you drop it, and later changes to the source tables aren't reflected.

**In SQL Server the syntax is `SELECT ... INTO`:**

```sql
SELECT
    CustomerID,
    SUM(Sales) AS total_sales
INTO Sales.CustomerSales_Snapshot       -- creates the new table
FROM Sales.Orders
GROUP BY CustomerID;
```

**In most other databases it's `CREATE TABLE ... AS SELECT`:**

```sql
-- PostgreSQL, MySQL, Oracle, Snowflake, BigQuery
CREATE TABLE customer_sales_snapshot AS
SELECT CustomerID, SUM(Sales) AS total_sales
FROM orders
GROUP BY CustomerID;
```

(SQL Server's own engine doesn't support `CREATE TABLE AS SELECT`. Azure Synapse does, under the name CTAS.)

### Use cases

- **Staging tables** in ETL: land and reshape data before loading it into its final home.
- **Snapshots and backups:** freeze the data as of a moment in time (month-end, before a risky change).
- **Pre-computed reporting tables:** run a heavy query once, and let dashboards read the small result table.
- **Copying a table** (with its data or just its structure).
- **Test and development copies** of production data.
- **Speeding up repeated heavy queries** by materialising an expensive join or aggregation.

**Copy just the structure, no rows:**

```sql
SELECT * INTO Sales.Orders_Copy FROM Sales.Orders WHERE 1 = 0;
```

**Append to a table that already exists:** use `INSERT INTO ... SELECT` instead (`SELECT INTO` fails if the table exists):

```sql
INSERT INTO Sales.CustomerSales_Snapshot (CustomerID, total_sales)
SELECT CustomerID, SUM(Sales) FROM Sales.Orders GROUP BY CustomerID;
```

### Pros and cons

| Pros                                               | Cons                                                                                                                                 |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Fast to read: the work was done once               | **Goes stale** until you rebuild it                                                                                            |
| Can be indexed and have constraints added          | Takes disk space                                                                                                                     |
| Shared by everyone, survives sessions              | Must be dropped and rebuilt (or truncated and reloaded) to refresh                                                                   |
| Good for reusing heavy results across many queries | Doesn't copy indexes, primary keys, constraints or triggers from the source (it does copy column types, nullability and`IDENTITY`) |
|                                                    | Needs`CREATE TABLE` permission and housekeeping                                                                                    |

> **Refreshing a snapshot:** `DROP TABLE IF EXISTS ...` then `SELECT INTO` again, or `TRUNCATE TABLE` and `INSERT ... SELECT`. Schedule this (an ETL job) if the table should stay reasonably current.

---

# 5. Temp Table

A **real table created in `tempdb`** that **disappears automatically** when its scope ends. It stores data (like CTAS) but cleans up after itself.

```sql
-- local temp table (single #): visible only to your session
SELECT CustomerID, SUM(Sales) AS total_sales
INTO #CustomerSales
FROM Sales.Orders
GROUP BY CustomerID;

SELECT * FROM #CustomerSales WHERE total_sales > 100;

DROP TABLE IF EXISTS #CustomerSales;      -- optional: tidy up early
```

Or define it explicitly first:

```sql
CREATE TABLE #CustomerSales (
    CustomerID  INT,
    total_sales INT
);

INSERT INTO #CustomerSales
SELECT CustomerID, SUM(Sales) FROM Sales.Orders GROUP BY CustomerID;

CREATE INDEX IX_total ON #CustomerSales (total_sales);   -- you can index it
```

### Kinds of temporary storage in SQL Server

|                             | Syntax                     | Visible to                             | Dropped when                                             |
| --------------------------- | -------------------------- | -------------------------------------- | -------------------------------------------------------- |
| **Local temp table**  | `#name`                  | Your session (and procedures it calls) | Session ends, procedure that created it ends, or`DROP` |
| **Global temp table** | `##name`                 | **All** sessions                 | Creating session ends and nobody else is using it        |
| **Table variable**    | `DECLARE @t TABLE (...)` | Current batch only                     | End of the batch                                         |

Table variables are fine for small row counts. Temp tables are better for larger data, because they have **statistics** (so the optimiser plans better) and can have indexes.

### Use cases

- **Multi-step processing:** run step 1, store the result, then run steps 2 and 3 on it.
- **Reusing an expensive result** several times without recomputing it (unlike a CTE).
- **Breaking up a huge query** so the optimiser handles smaller pieces better.
- **Debugging:** inspect intermediate results between steps.
- **Stored procedures and ETL** that need scratch space.
- **Indexing an intermediate result** before a big join.

### Pros and cons

| Pros                                                          | Cons                                                                              |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Stores data, so an expensive result is computed**once** | Uses`tempdb` (shared by the whole server)                                       |
| Can be indexed and has statistics                             | **Snapshot:** doesn't see later changes to the source                       |
| Auto-cleanup, private to your session by default              | Gone after the session, so it can't be shared across sessions (use`##` or CTAS) |
| Can be modified freely (`INSERT`/`UPDATE`/`DELETE`)     | Many creates/drops in a busy system can cause`tempdb` contention and recompiles |

---

# The Same Task Five Ways

**Task:** list customers whose total sales are above 100, with their total.

All five give this result:

| CustomerID | FirstName | LastName | total_sales |
| ---------- | --------- | -------- | ----------- |
| 1          | Jossef    | Goldberg | 130         |
| 3          | Mary      | Dury     | 155         |

**1. Subquery**

```sql
SELECT c.CustomerID, c.FirstName, c.LastName, t.total_sales
FROM Sales.Customers AS c
JOIN (
    SELECT CustomerID, SUM(Sales) AS total_sales
    FROM Sales.Orders
    GROUP BY CustomerID
) AS t ON t.CustomerID = c.CustomerID
WHERE t.total_sales > 100;
```

**2. CTE**

```sql
WITH CTE_total_sales AS (
    SELECT CustomerID, SUM(Sales) AS total_sales
    FROM Sales.Orders
    GROUP BY CustomerID
)
SELECT c.CustomerID, c.FirstName, c.LastName, t.total_sales
FROM Sales.Customers AS c
JOIN CTE_total_sales AS t ON t.CustomerID = c.CustomerID
WHERE t.total_sales > 100;
```

**3. View**

```sql
CREATE VIEW Sales.V_Customer_Sales AS
SELECT CustomerID, SUM(Sales) AS total_sales
FROM Sales.Orders
GROUP BY CustomerID;
GO

SELECT c.CustomerID, c.FirstName, c.LastName, v.total_sales
FROM Sales.Customers AS c
JOIN Sales.V_Customer_Sales AS v ON v.CustomerID = c.CustomerID
WHERE v.total_sales > 100;
```

**4. CTAS (`SELECT INTO` a permanent table)**

```sql
SELECT CustomerID, SUM(Sales) AS total_sales
INTO Sales.CustomerSales
FROM Sales.Orders
GROUP BY CustomerID;

SELECT c.CustomerID, c.FirstName, c.LastName, t.total_sales
FROM Sales.Customers AS c
JOIN Sales.CustomerSales AS t ON t.CustomerID = c.CustomerID
WHERE t.total_sales > 100;
```

**5. Temp table**

```sql
SELECT CustomerID, SUM(Sales) AS total_sales
INTO #CustomerSales
FROM Sales.Orders
GROUP BY CustomerID;

SELECT c.CustomerID, c.FirstName, c.LastName, t.total_sales
FROM Sales.Customers AS c
JOIN #CustomerSales AS t ON t.CustomerID = c.CustomerID
WHERE t.total_sales > 100;

DROP TABLE #CustomerSales;
```

For a task this small, **options 1 and 2 are the right choice**. The others add objects you have to manage and don't give anything back. They pay off when the result is reused, shared or expensive.

---

# Fresh Data vs Snapshot

Add a new order that pushes Kevin (customer 2) from 95 to 115:

```sql
INSERT INTO Sales.Orders VALUES (12, 101, 2, '2025-03-25', 20);
```

Now re-run each approach from the example above:

| Approach   | Customer 2 (Kevin) in the result? | Why                                            |
| ---------- | --------------------------------- | ---------------------------------------------- |
| Subquery   | **Yes** (115)               | Re-runs against the live table                 |
| CTE        | **Yes** (115)               | Re-runs against the live table                 |
| View       | **Yes** (115)               | Re-runs its saved query each time              |
| CTAS table | **No**                      | Holds the totals from when it was created (95) |
| Temp table | **No**                      | Holds the totals from when it was created (95) |

Neither a CTAS table nor a temp table updates itself. That's the trade-off: **speed and reuse in exchange for freshness.** Decide how stale is acceptable, and rebuild on a schedule if needed.

---

# Performance Notes

|                        | What really happens                                                                                                                                                                             |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Subquery**     | Merged into the outer query's plan. Usually the same plan as the equivalent join                                                                                                                |
| **CTE**          | Same as a subquery in SQL Server:**re-evaluated per reference**, not cached. (PostgreSQL 12+ inlines it too, unless it's referenced several times, recursive, or marked `MATERIALIZED`) |
| **View**         | Expanded into the outer query each time. Adds no speed on its own                                                                                                                               |
| **Indexed view** | The only view type that stores results. Faster reads, slower writes                                                                                                                             |
| **CTAS**         | Work done once at creation. Later reads are cheap, and you can index it                                                                                                                         |
| **Temp table**   | Work done once. Has statistics and indexes. Costs`tempdb` I/O                                                                                                                                 |

Rules of thumb:

- **If the same expensive logic runs many times**, store it: a temp table (within a process) or a CTAS table (across processes and users).
- **If it runs once**, a subquery or CTE is cheapest and simplest.
- **Don't assume a CTE or view is faster.** They're about readability, reuse and security. Check the execution plan if performance matters.
- **A big intermediate result joined many times** often runs faster as an indexed temp table than as a CTE.

---

# Decision Guide

| If you need...                                                         | Use                                     |
| ---------------------------------------------------------------------- | --------------------------------------- |
| A quick filter or one-off lookup (`IN`, `EXISTS`, "above average") | **Subquery**                      |
| A single computed value next to each row                               | **Subquery** (scalar)             |
| A complex query split into readable steps                              | **CTE**                           |
| To filter on a window function (rank, row number)                      | **CTE** (or subquery in `FROM`) |
| A hierarchy or a number/date series                                    | **Recursive CTE**                 |
| One query shared by many people or reports                             | **View**                          |
| To hide columns or rows from users                                     | **View** (plus permissions)       |
| Always-current data with a stable interface                            | **View**                          |
| A result frozen at a point in time                                     | **CTAS**                          |
| A staging table or reporting table that persists                       | **CTAS**                          |
| An expensive result reused across many queries or users                | **CTAS** (or an indexed view)     |
| An expensive result reused several times in one session or procedure   | **Temp table**                    |
| Scratch space with auto-cleanup                                        | **Temp table**                    |
| To index an intermediate result before a big join                      | **Temp table**                    |

**A simple way to choose:**

1. Used once, in one query? **Subquery or CTE.**
2. Used by many people or queries, and must be current? **View.**
3. Used many times and expensive, only in one process? **Temp table.**
4. Needs to persist or be shared as stored data? **CTAS table.**

---

# Dialect Differences

|                               | SQL Server                    | PostgreSQL                               | MySQL                            | Oracle                                                                                        |
| ----------------------------- | ----------------------------- | ---------------------------------------- | -------------------------------- | --------------------------------------------------------------------------------------------- |
| **CTE**                 | `WITH`                      | `WITH` (`WITH RECURSIVE`)            | `WITH` (8.0+)                  | `WITH`                                                                                      |
| **Recursive keyword**   | None (just self-reference)    | `WITH RECURSIVE`                       | `WITH RECURSIVE`               | None                                                                                          |
| **CTAS**                | `SELECT ... INTO new_table` | `CREATE TABLE t AS SELECT ...`         | `CREATE TABLE t AS SELECT ...` | `CREATE TABLE t AS SELECT ...`                                                              |
| **Temp table**          | `#t` / `##t`              | `CREATE TEMP TABLE t ...`              | `CREATE TEMPORARY TABLE t ...` | `CREATE GLOBAL TEMPORARY TABLE t ...` (structure is permanent, data is private per session) |
| **Replace a view**      | `CREATE OR ALTER VIEW`      | `CREATE OR REPLACE VIEW`               | `CREATE OR REPLACE VIEW`       | `CREATE OR REPLACE VIEW`                                                                    |
| **Stored-results view** | Indexed view                  | `MATERIALIZED VIEW` (refresh manually) | Not built in                     | `MATERIALIZED VIEW`                                                                         |

PostgreSQL and Oracle also have **materialised views**: views that store their results and are refreshed on demand or on a schedule. That sits between a view and a CTAS table.

---

## Common Mistakes

1. **Treating a CTE as stored data.** It's re-run on every reference, so a heavy CTE used three times runs three times.
2. **Expecting a view to be faster.** It's the same query run again. Use an indexed view or a CTAS table if you need stored results.
3. **Forgetting CTAS and temp tables are snapshots.** They don't update when the source changes. This causes stale reports.
4. **Using `NOT IN` with a subquery that can return `NULL`.** It returns nothing. Use `NOT EXISTS`.
5. **A scalar subquery returning several rows.** `Subquery returned more than 1 value.`
6. **Leaving permanent tables behind.** CTAS tables stay until dropped. Name them clearly (a `staging_` or `_snapshot` suffix) and clean up.
7. **Creating a temp table you only use once.** A subquery or CTE is simpler.
8. **Expecting a temp table to be visible in another session.** A single `#` is private to your session.
9. **Re-running `SELECT INTO` on an existing table.** It fails. Drop it first (`DROP TABLE IF EXISTS`) or use `INSERT ... SELECT`.
10. **Building views on views on views.** Each layer adds joins and makes debugging harder.
11. **Assuming CTAS copies indexes and keys.** It copies the data and basic column definitions. Add indexes and constraints yourself.
12. **Missing the semicolon before `WITH`.** `Incorrect syntax near the keyword 'WITH'.`

---

## Cheat Sheet

|                          | Subquery                | CTE                 | View              | CTAS                                  | Temp table                     |
| ------------------------ | ----------------------- | ------------------- | ----------------- | ------------------------------------- | ------------------------------ |
| **Create with**    | `(SELECT ...)` inline | `WITH x AS (...)` | `CREATE VIEW`   | `SELECT INTO` / `CREATE TABLE AS` | `#t` / `CREATE TEMP TABLE` |
| **Stores data**    | No                      | No                  | No                | **Yes**                         | **Yes**                  |
| **Data is**        | Live                    | Live                | Live              | Snapshot                              | Snapshot                       |
| **Lifetime**       | Statement               | Statement           | Until dropped     | Until dropped                         | Session                        |
| **Shared**         | No                      | No                  | Yes               | Yes                                   | No (`#`) / Yes (`##`)      |
| **Indexable**      | No                      | No                  | Indexed view only | Yes                                   | Yes                            |
| **Recursive**      | No                      | **Yes**       | No                | No                                    | No                             |
| **Cleanup needed** | No                      | No                  | Maybe             | **Yes**                         | Automatic                      |
| **Best for**       | Quick filters           | Readable steps      | Reuse, security   | Persisted results                     | Scratch work                   |

**Memory aid:**

- **Subquery:** "inline, one-off"
- **CTE:** "named steps, one statement"
- **View:** "saved query, always live"
- **CTAS:** "saved copy, stays until dropped"
- **Temp table:** "scratch copy, auto-dropped"
