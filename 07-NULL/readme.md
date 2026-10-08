
# SQL NULL Handling

A quick reference for dealing with `NULL` in SQL Server (T-SQL): `ISNULL`, `COALESCE`, `NULLIF`, `IS NULL` / `IS NOT NULL`, and common use cases (aggregations, sorting, joins, anti joins).

`NULL` means "unknown / missing". Anything you do with it (`+`, `-`, `||`, `=`, `>`) gives `NULL` or UNKNOWN, which is why it needs explicit handling.

---

## Table of Contents

- [Sample Data](#sample-data)
- [ISNULL](#isnull)
- [COALESCE](#coalesce)
- [ISNULL vs COALESCE](#isnull-vs-coalesce)
- [Use Case: Aggregations](#use-case-aggregations)
- [Use Case: Strings and Math](#use-case-strings-and-math)
- [Use Case: Sorting NULLs Last](#use-case-sorting-nulls-last)
- [Use Case: Joining on Columns With NULLs](#use-case-joining-on-columns-with-nulls)
- [NULLIF](#nullif)
- [IS NULL / IS NOT NULL](#is-null--is-not-null)
- [Use Case: Anti Joins](#use-case-anti-joins)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Sample Data

```sql
CREATE SCHEMA Sales;
GO

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

CREATE TABLE Sales.Orders (
    OrderID    INT PRIMARY KEY,
    CustomerID INT,
    Sales      INT,
    Quantity   INT
);

INSERT INTO Sales.Orders VALUES
(1001, 1, 10, 2),
(1002, 2, 15, 3),
(1003, 3, 20, 0),
(1004, 1, 25, 5);
```

**Sales.Customers**

| CustomerID | FirstName | LastName | Country | Score |
| ---------- | --------- | -------- | ------- | ----- |
| 1          | Jossef    | Goldberg | Germany | 350   |
| 2          | Kevin     | Brown    | USA     | 900   |
| 3          | Mary      | NULL     | USA     | 750   |
| 4          | Mark      | Schwarz  | Germany | 500   |
| 5          | Anna      | Adams    | USA     | NULL  |

**Sales.Orders**

| OrderID | CustomerID | Sales | Quantity |
| ------- | ---------- | ----- | -------- |
| 1001    | 1          | 10    | 2        |
| 1002    | 2          | 15    | 3        |
| 1003    | 3          | 20    | 0        |
| 1004    | 1          | 25    | 5        |

Mary has no last name, Anna has no score, and order 1003 has a quantity of 0. Customers 4 and 5 have no orders.

---

## ISNULL

`ISNULL(value, replacement)` replaces `NULL` with something else.

- The replacement can be a **hardcoded value** or **another column** from the same row.
- If the replacement column is also `NULL` in that row, the result is `NULL`.
- It takes **exactly two** arguments.

```sql
SELECT
    CustomerID,
    Score,
    ISNULL(Score, 0)           AS score_or_zero,      -- hardcoded replacement
    LastName,
    ISNULL(LastName, FirstName) AS last_or_first      -- another column
FROM Sales.Customers;
```

| CustomerID | Score | score_or_zero | LastName | last_or_first |
| ---------- | ----- | ------------- | -------- | ------------- |
| 1          | 350   | 350           | Goldberg | Goldberg      |
| 2          | 900   | 900           | Brown    | Brown         |
| 3          | 750   | 750           | NULL     | Mary          |
| 4          | 500   | 500           | Schwarz  | Schwarz       |
| 5          | NULL  | 0             | Adams    | Adams         |

**Same function, different names:**

| Database   | Function         |
| ---------- | ---------------- |
| SQL Server | `ISNULL(a, b)` |
| Oracle     | `NVL(a, b)`    |
| MySQL      | `IFNULL(a, b)` |

> In MySQL, `ISNULL(x)` with **one** argument is a different function that returns 1 or 0.

---

## COALESCE

`COALESCE(a, b, c, ...)` returns the **first non-NULL value** in the list. It checks each value in order and moves on whenever it finds `NULL`.

```sql
SELECT COALESCE(NULL, NULL, 'third', 'fourth') AS result;   -- third
```

- Accepts **any number** of arguments.
- Works in **all databases** (it's standard SQL), so queries are easy to migrate.
- If every value is `NULL`, it returns `NULL`. Add a final hardcoded fallback to avoid that.

```sql
-- first available contact method, with a final fallback
COALESCE(mobile, home_phone, work_phone, 'no phone')
```

---

## ISNULL vs COALESCE

|                  | `ISNULL`                                      | `COALESCE`                             |
| ---------------- | ----------------------------------------------- | ---------------------------------------- |
| Arguments        | Exactly 2                                       | Any number                               |
| Portability      | SQL Server only (`NVL`, `IFNULL` elsewhere) | All databases                            |
| Result data type | Type of the**first** argument             | Highest-precedence type of all arguments |
| Performance      | Marginally faster in some cases                 | Marginally slower in some cases          |

The performance difference is negligible in practice, so default to `COALESCE` for portability.

> ⚠️ **`ISNULL` can silently truncate.** The result takes the first argument's type:
>
> ```sql
> DECLARE @x VARCHAR(3) = NULL;
> SELECT ISNULL(@x, 'unknown');    -- 'unk'
> SELECT COALESCE(@x, 'unknown');  -- 'unknown'
> ```

---

## Use Case: Aggregations

Handle `NULL` **before** aggregating. `AVG`, `SUM`, `MIN` and `MAX` ignore `NULL`s, and `AVG` divides by the number of non-null values, not the number of rows.

```sql
SELECT
    CustomerID,
    Score,
    AVG(Score) OVER ()                AS avgscore1,
    AVG(COALESCE(Score, 0)) OVER ()   AS avgscore2
FROM Sales.Customers;
```

| CustomerID | Score | avgscore1 | avgscore2 |
| ---------- | ----- | --------- | --------- |
| 1          | 350   | 625       | 500       |
| 2          | 900   | 625       | 500       |
| 3          | 750   | 625       | 500       |
| 4          | 500   | 625       | 500       |
| 5          | NULL  | 625       | 500       |

- `avgscore1`: Anna's `NULL` is ignored, so it's (350 + 900 + 750 + 500) / **4** = 625.
- `avgscore2`: `NULL` becomes 0, so it's 2500 / **5** = 500.

Neither is "right". Decide whether a missing score means "unknown, exclude it" or "zero".

---

## Use Case: Strings and Math

Concatenating or adding with `NULL` gives `NULL`, so replace it first.

```sql
-- full name in one field, plus 10 bonus points on the score
SELECT
    CustomerID,
    FirstName,
    LastName,
    FirstName + ' ' + COALESCE(LastName, '') AS full_name,
    Score,
    COALESCE(Score, 0) + 10                  AS score_with_bonus
FROM Sales.Customers;
```

| CustomerID | FirstName | LastName | full_name                  | Score | score_with_bonus |
| ---------- | --------- | -------- | -------------------------- | ----- | ---------------- |
| 1          | Jossef    | Goldberg | Jossef Goldberg            | 350   | 360              |
| 2          | Kevin     | Brown    | Kevin Brown                | 900   | 910              |
| 3          | Mary      | NULL     | `Mary ` (trailing space) | 750   | 760              |
| 4          | Mark      | Schwarz  | Mark Schwarz               | 500   | 510              |
| 5          | Anna      | Adams    | Anna Adams                 | NULL  | 10               |

Without `COALESCE`, `FirstName + ' ' + LastName` would give `NULL` for Mary, and `Score + 10` would give `NULL` for Anna.

> **Two things to watch:**
>
> - Mary's name ends with a trailing space. Wrap it in `TRIM(...)`, or use `CONCAT_WS(' ', FirstName, LastName)` (SQL Server 2017+), which skips `NULL`s and doesn't add the separator for them.
> - Anna ends up with 10 points for having no score. If "no score" should stay "no score", leave the `NULL` alone.

---

## Use Case: Sorting NULLs Last

In SQL Server, `NULL` is treated as the **lowest** value, so it comes **first** in an ascending sort. To push `NULL`s to the end:

**Method 1: replace `NULL` with a very big number**

```sql
SELECT
    CustomerID,
    Score,
    COALESCE(Score, 9999999) AS score_for_sorting
FROM Sales.Customers
ORDER BY COALESCE(Score, 9999999);
```

| CustomerID | Score | score_for_sorting |
| ---------- | ----- | ----------------- |
| 1          | 350   | 350               |
| 4          | 500   | 500               |
| 3          | 750   | 750               |
| 2          | 900   | 900               |
| 5          | NULL  | 9999999           |

**Method 2: sort on a `NULL` flag first (more robust)**

```sql
SELECT CustomerID, Score
FROM Sales.Customers
ORDER BY CASE WHEN Score IS NULL THEN 1 ELSE 0 END, Score;
```

| CustomerID | Score |
| ---------- | ----- |
| 1          | 350   |
| 4          | 500   |
| 3          | 750   |
| 2          | 900   |
| 5          | NULL  |

Method 1 breaks if a real value is ever bigger than your magic number, and it needs rethinking for descending sorts. Method 2 has no magic number and doesn't change the displayed values.

> PostgreSQL and Oracle sort `NULL`s last by default and support `ORDER BY Score NULLS LAST` / `NULLS FIRST`. SQL Server doesn't have that syntax.

---

## Use Case: Joining on Columns With NULLs

`NULL = NULL` is never true, so rows with `NULL` join keys **never match**:

```sql
-- rows where a.region and b.region are both NULL are NOT matched
SELECT *
FROM table_a AS a
JOIN table_b AS b
    ON a.region = b.region;
```

To make `NULL`s match each other, either:

```sql
-- option 1: replace NULL with a placeholder on both sides
ON COALESCE(a.region, '') = COALESCE(b.region, '')

-- option 2: explicit NULL check
ON a.region = b.region
   OR (a.region IS NULL AND b.region IS NULL)
```

Option 1 also matches `NULL` with an empty string, and both options usually prevent index use, so only use them when you need them.

---

## NULLIF

`NULLIF(a, b)` compares two expressions:

- Returns **`NULL`** if they are equal.
- Returns the **first value** if they are not.

**Main use case: preventing division by zero.** Dividing by `NULL` gives `NULL`, but dividing by 0 gives an error.

```sql
-- price per unit = sales / quantity
SELECT
    OrderID,
    Sales,
    Quantity,
    Sales / NULLIF(Quantity, 0) AS price
FROM Sales.Orders;
```

| OrderID | Sales | Quantity | price |
| ------- | ----- | -------- | ----- |
| 1001    | 10    | 2        | 5     |
| 1002    | 15    | 3        | 5     |
| 1003    | 20    | 0        | NULL  |
| 1004    | 25    | 5        | 5     |

Order 1003 returns `NULL` instead of crashing the whole query. To show 0 instead, combine the two:

```sql
COALESCE(Sales / NULLIF(Quantity, 0), 0) AS price
```

> `Sales` and `Quantity` are integers here, so SQL Server does integer division (`7 / 2 = 3`). Use `Sales * 1.0 / NULLIF(Quantity, 0)` to keep decimals.

**Another use: turn empty strings into `NULL`:**

```sql
NULLIF(LastName, '')
```

---

## IS NULL / IS NOT NULL

| Operator        | Returns true when        |
| --------------- | ------------------------ |
| `IS NULL`     | The value is`NULL`     |
| `IS NOT NULL` | The value is not`NULL` |

Use them to search for missing (or present) information. Never use `= NULL` or `<> NULL`, which are always UNKNOWN.

```sql
-- customers who have no score
SELECT * FROM Sales.Customers
WHERE Score IS NULL;
```

| CustomerID | FirstName | LastName | Country | Score |
| ---------- | --------- | -------- | ------- | ----- |
| 5          | Anna      | Adams    | USA     | NULL  |

```sql
-- customers who have a score
SELECT * FROM Sales.Customers
WHERE Score IS NOT NULL;
```

Returns customers 1, 2, 3 and 4.

---

## Use Case: Anti Joins

`IS NULL` is what makes anti joins work: a `LEFT JOIN` leaves `NULL`s on the right side for unmatched rows, and you filter for those.

```sql
-- customers who have not placed any orders
SELECT
    c.*,
    o.OrderID
FROM Sales.Customers AS c
LEFT JOIN Sales.Orders AS o
    ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL;
```

| CustomerID | FirstName | LastName | Country | Score | OrderID |
| ---------- | --------- | -------- | ------- | ----- | ------- |
| 4          | Mark      | Schwarz  | Germany | 500   | NULL    |
| 5          | Anna      | Adams    | USA     | NULL  | NULL    |

- Filter on a column that is **never NULL when a match exists**, like the primary key `OrderID`. Filtering on a nullable column like `Sales` would give wrong results.
- `o.OrderID` in the `SELECT` is always `NULL` here, so you can drop it from the output.

---

## Common Gotchas

1. **Any operation with `NULL` returns `NULL`.** `5 + NULL`, `'a' + NULL`, `NULL > 3` are all `NULL` or UNKNOWN.
2. **`= NULL` never works.** Use `IS NULL`.
3. **`AVG`, `SUM`, `COUNT(column)` ignore `NULL`s.** `COUNT(*)` counts rows, `COUNT(Score)` counts non-null scores.
4. **`NOT IN` with a `NULL` in the list returns no rows.** Use `NOT EXISTS`, or filter the `NULL`s out of the list.
5. **`ISNULL` takes the first argument's data type** and can truncate the replacement value.
6. **Sorting:** SQL Server puts `NULL` first in ascending order.
7. **Replacing `NULL` with 0 changes the meaning** of your data (averages, counts). Decide whether "missing" means "unknown" or "zero".
8. **`NULL` join keys never match** unless you handle them explicitly.

---

## Cheat Sheet

| Function / Operator     | Purpose                                         | Example                             |
| ----------------------- | ----------------------------------------------- | ----------------------------------- |
| `ISNULL(a, b)`        | Replace`NULL` with `b` (SQL Server, 2 args) | `ISNULL(Score, 0)`                |
| `NVL(a, b)`           | Oracle's`ISNULL`                              | `NVL(Score, 0)`                   |
| `IFNULL(a, b)`        | MySQL's`ISNULL`                               | `IFNULL(Score, 0)`                |
| `COALESCE(a, b, ...)` | First non-`NULL` value (all databases)        | `COALESCE(mobile, phone, 'none')` |
| `NULLIF(a, b)`        | `NULL` if equal, otherwise `a`              | `Sales / NULLIF(Quantity, 0)`     |
| `IS NULL`             | Is the value`NULL`?                           | `WHERE Score IS NULL`             |
| `IS NOT NULL`         | Is the value not`NULL`?                       | `WHERE Score IS NOT NULL`         |

**Quick rules:**

- Need a fallback value? `COALESCE`.
- Need to prevent divide-by-zero? `NULLIF`.
- Need to find missing data or unmatched rows? `IS NULL`.
- Doing maths, string concatenation or aggregation? Deal with `NULL`s first.
