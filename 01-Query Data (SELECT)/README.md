
# SQL Basics: Core Query Clauses (T-SQL / SQL Server)

The clauses in this note appear in almost every query I will write. Practised on the `SalesDB` database (`customers` and `orders` tables) in SQL Server.

**Files:** `basic-clauses.sql` holds the full annotated queries.

---

## Quick reference

| Clause       | What it does                                  | Key rule                                                     |
| ------------ | --------------------------------------------- | ------------------------------------------------------------ |
| `SELECT`   | Chooses which columns appear in the output    | Column order in`SELECT` is the column order of the result  |
| `FROM`     | Says which table the data comes from          | Runs first                                                   |
| `WHERE`    | Filters**rows** before any grouping     | Cannot use aggregates like`SUM()`                          |
| `GROUP BY` | Collapses rows into groups, one row per group | Every`SELECT` column must be aggregated or in `GROUP BY` |
| `HAVING`   | Filters**groups** after aggregation     | Use for conditions on`SUM`, `AVG`, `COUNT`             |
| `DISTINCT` | Removes duplicate rows from the result        | Can slow queries down, only use when needed                  |
| `ORDER BY` | Sorts the result                              | `ASC` is the default, `DESC` for highest first           |
| `TOP n`    | Limits output to the first`n` rows          | Pair with`ORDER BY` or the rows are arbitrary              |

---

## Coding order vs execution order

The order I **write** a query is not the order SQL **runs** it. This is the single most useful thing to remember when debugging.

**Coding order (how I write it)**

```sql
SELECT DISTINCT TOP 2
    col1,
    SUM(col2)
FROM table
WHERE col = 10
GROUP BY col1
HAVING SUM(col2) > 30
ORDER BY col1 ASC
```

**Execution order (how SQL runs it)**

1. `FROM`
2. `WHERE`
3. `GROUP BY`
4. `HAVING`
5. `SELECT` / `DISTINCT`
6. `ORDER BY`
7. `TOP`

Why it matters:

- `WHERE` runs before `GROUP BY`, so it cannot filter on aggregates. That is what `HAVING` is for.
- `SELECT` runs late, so a column alias defined there (e.g. `total_score`) does not exist yet in `WHERE` or `HAVING`. It can be used in `ORDER BY`, which runs after.

---

## Examples

### Selecting columns

```sql
-- all data
SELECT * FROM customers;

-- specific columns; output follows this column order
SELECT first_name, country, score
FROM customers;
```

### WHERE: filter rows

```sql
-- score not equal to 0
SELECT *
FROM customers
WHERE score != 0;

-- customers from Germany
SELECT *
FROM customers
WHERE country = 'Germany';
```

### ORDER BY: sort results

```sql
-- highest score first
SELECT * FROM customers
ORDER BY score DESC;

-- lowest score first (ASC is the default, but writing it is good practice)
SELECT * FROM customers
ORDER BY score ASC;

-- nested sort: country A-Z, then highest score within each country
SELECT * FROM customers
ORDER BY country ASC, score DESC;
```

The order of columns in a nested `ORDER BY` matters. The first column sorts first, the second only breaks ties.

### GROUP BY: aggregate per group

**Rule:** every column in `SELECT` must be either aggregated or listed in `GROUP BY`. Selecting `first_name` here would throw an error.

```sql
-- total score per country
SELECT
    country,
    SUM(score) AS total_score
FROM customers
GROUP BY country;

-- total score and number of customers per country
SELECT
    country,
    SUM(score)     AS total_score,
    COUNT(country) AS num_of_customers
FROM customers
GROUP BY country;
```

### HAVING: filter after aggregation

`WHERE` filters before grouping, `HAVING` filters after.

```sql
-- average score per country, ignoring customers with score 0,
-- keeping only countries whose average is above 430
SELECT
    country,
    AVG(score) AS avg_score
FROM customers
WHERE score != 0          -- filters rows first
GROUP BY country
HAVING AVG(score) > 430;  -- filters groups second
```

### DISTINCT: remove duplicates

```sql
-- unique list of countries
SELECT DISTINCT country
FROM customers;
```

Avoid `DISTINCT` unless it is genuinely needed. It forces extra work and can slow a query down. If duplicates show up unexpectedly, the real fix is often a join or filter issue upstream.

### TOP: limit rows

```sql
-- any 3 customers
SELECT TOP 3 *
FROM customers;

-- the 3 customers with the highest scores
SELECT TOP 3 *
FROM customers
ORDER BY score DESC;

-- the 2 most recent orders
SELECT TOP 2 *
FROM orders
ORDER BY order_date DESC;
```

`TOP` without `ORDER BY` returns an arbitrary set of rows, so "top" only means something when a sort comes with it.

---

## Things to remember

- `WHERE` = filter rows, `HAVING` = filter groups.
- Aliases (`AS total_score`) only exist from `SELECT` onwards. Not in `WHERE`, but usable in `ORDER BY`.
- `COUNT(column)` skips `NULL` values, while `COUNT(*)` counts every row. Pick deliberately.
- `!=` and `<>` both mean "not equal" in SQL Server. `<>` is the ANSI standard and works in every database.
- `TOP` is T-SQL syntax. In MySQL, PostgreSQL, BigQuery and Snowflake the equivalent is `LIMIT n` at the end of the query.

---

## Next up

Joins, set operators, and functions, in the folders that follow this one.
