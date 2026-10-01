
# SQL `WHERE` Clause & Operators

A quick reference for filtering rows in SQL using `WHERE` and its most common operators: `AND`, `OR`, `NOT`, `LIKE`, `BETWEEN`, `IN`, plus `NULL` handling.

All examples use one small sample table so you can run them yourself and compare results.

---

## Table of Contents

- [Sample Data](#sample-data)
- [WHERE Basics](#where-basics)
- [Comparison Operators](#comparison-operators)
- [AND](#and)
- [OR](#or)
- [NOT](#not)
- [Operator Precedence](#operator-precedence)
- [LIKE](#like)
- [BETWEEN](#between)
- [IN](#in)
- [NULL Handling](#null-handling)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Sample Data

```sql
CREATE TABLE employees (
    id          INT PRIMARY KEY,
    name        VARCHAR(50),
    department  VARCHAR(30),
    salary      INT,
    hire_date   DATE,
    city        VARCHAR(30)
);

INSERT INTO employees VALUES
(1, 'Alice Smith',  'Engineering', 75000, '2021-03-15', 'London'),
(2, 'Bob Jones',    'Marketing',   52000, '2019-07-01', 'Manchester'),
(3, 'Carol White',  'Engineering', 88000, '2018-11-20', 'London'),
(4, 'David Brown',  'Sales',       45000, '2022-01-10', 'Birmingham'),
(5, 'Emma Davis',   'Marketing',   61000, '2020-05-25', 'London'),
(6, 'Frank Miller', 'Sales',       58000, '2017-09-03', 'Leeds'),
(7, 'Grace Lee',    'HR',          49000, '2023-02-14', 'Manchester'),
(8, 'Henry Wilson', 'Engineering', NULL,  '2024-06-01', 'Leeds');
```

| id | name         | department  | salary | hire_date  | city       |
| -- | ------------ | ----------- | ------ | ---------- | ---------- |
| 1  | Alice Smith  | Engineering | 75000  | 2021-03-15 | London     |
| 2  | Bob Jones    | Marketing   | 52000  | 2019-07-01 | Manchester |
| 3  | Carol White  | Engineering | 88000  | 2018-11-20 | London     |
| 4  | David Brown  | Sales       | 45000  | 2022-01-10 | Birmingham |
| 5  | Emma Davis   | Marketing   | 61000  | 2020-05-25 | London     |
| 6  | Frank Miller | Sales       | 58000  | 2017-09-03 | Leeds      |
| 7  | Grace Lee    | HR          | 49000  | 2023-02-14 | Manchester |
| 8  | Henry Wilson | Engineering | NULL   | 2024-06-01 | Leeds      |

> Henry's salary is deliberately `NULL` to show how `NULL` behaves in filters.

---

## WHERE Basics

`WHERE` filters rows. Only rows where the condition evaluates to **TRUE** are kept. Rows that evaluate to **FALSE** or **UNKNOWN** (anything involving `NULL`) are dropped.

```sql
SELECT column1, column2
FROM table_name
WHERE condition;
```

`WHERE` also works with `UPDATE` and `DELETE`:

```sql
UPDATE employees SET city = 'London' WHERE id = 7;
DELETE FROM employees WHERE id = 8;
```

> ⚠️ An `UPDATE` or `DELETE` without a `WHERE` clause hits **every row** in the table.

**Example**

```sql
SELECT name, department
FROM employees
WHERE department = 'Engineering';
```

| name         | department  |
| ------------ | ----------- |
| Alice Smith  | Engineering |
| Carol White  | Engineering |
| Henry Wilson | Engineering |

---

## Comparison Operators

| Operator         | Meaning                                   |
| ---------------- | ----------------------------------------- |
| `=`            | Equal to                                  |
| `<>` or `!=` | Not equal to (`<>` is the SQL standard) |
| `>`            | Greater than                              |
| `<`            | Less than                                 |
| `>=`           | Greater than or equal to                  |
| `<=`           | Less than or equal to                     |

```sql
SELECT name, salary
FROM employees
WHERE salary >= 60000;
```

| name        | salary |
| ----------- | ------ |
| Alice Smith | 75000  |
| Carol White | 88000  |
| Emma Davis  | 61000  |

- Text and dates go in **single quotes**: `'London'`, `'2021-03-15'`
- Numbers don't: `salary > 50000`

---

## AND

Returns a row only if **all** conditions are true.

```sql
SELECT name, department, salary
FROM employees
WHERE department = 'Engineering'
  AND salary > 70000;
```

| name        | department  | salary |
| ----------- | ----------- | ------ |
| Alice Smith | Engineering | 75000  |
| Carol White | Engineering | 88000  |

Henry isn't returned because `NULL > 70000` is UNKNOWN, not TRUE.

---

## OR

Returns a row if **at least one** condition is true.

```sql
SELECT name, city
FROM employees
WHERE city = 'Leeds'
   OR city = 'Birmingham';
```

| name         | city       |
| ------------ | ---------- |
| David Brown  | Birmingham |
| Frank Miller | Leeds      |
| Henry Wilson | Leeds      |

> 💡 Lots of `OR`s on the same column? Use [`IN`](#in) instead.

---

## NOT

Negates a condition.

```sql
SELECT name, department
FROM employees
WHERE NOT department = 'Engineering';
-- same as: WHERE department <> 'Engineering'
```

| name         | department |
| ------------ | ---------- |
| Bob Jones    | Marketing  |
| David Brown  | Sales      |
| Emma Davis   | Marketing  |
| Frank Miller | Sales      |
| Grace Lee    | HR         |

`NOT` pairs with other operators too:

```sql
WHERE name NOT LIKE 'A%'
WHERE salary NOT BETWEEN 50000 AND 65000
WHERE city NOT IN ('London', 'Leeds')
WHERE salary IS NOT NULL
```

---

## Operator Precedence

SQL evaluates logical operators in this order:

1. `NOT`
2. `AND`
3. `OR`

So `AND` binds tighter than `OR`, which can silently give you the wrong result.

**❌ Without parentheses**

```sql
SELECT name, department, salary
FROM employees
WHERE department = 'Sales'
   OR department = 'Marketing'
  AND salary > 55000;
```

This is read as `Sales OR (Marketing AND salary > 55000)`:

| name         | department | salary |
| ------------ | ---------- | ------ |
| David Brown  | Sales      | 45000  |
| Emma Davis   | Marketing  | 61000  |
| Frank Miller | Sales      | 58000  |

David slips through even though he earns 45000.

**✅ With parentheses**

```sql
SELECT name, department, salary
FROM employees
WHERE (department = 'Sales' OR department = 'Marketing')
  AND salary > 55000;
```

| name         | department | salary |
| ------------ | ---------- | ------ |
| Emma Davis   | Marketing  | 61000  |
| Frank Miller | Sales      | 58000  |

> **Rule of thumb:** whenever you mix `AND` and `OR`, use parentheses.

---

## LIKE

Pattern matching for text, using two wildcards:

| Wildcard | Matches                                   |
| -------- | ----------------------------------------- |
| `%`    | Any number of characters (including zero) |
| `_`    | Exactly one character                     |

**Common patterns**

| Pattern    | Meaning                             |
| ---------- | ----------------------------------- |
| `'A%'`   | Starts with A                       |
| `'%son'` | Ends with "son"                     |
| `'%an%'` | Contains "an" anywhere              |
| `'_r%'`  | Second character is "r"             |
| `'J___'` | Exactly 4 characters, starts with J |

**Examples**

```sql
SELECT name FROM employees WHERE name LIKE 'A%';
-- Alice Smith

SELECT name FROM employees WHERE name LIKE '%son';
-- Henry Wilson

SELECT name FROM employees WHERE name LIKE '_r%';
-- Frank Miller, Grace Lee
```

**Matching a literal `%` or `_`**

Use `ESCAPE` to define an escape character:

```sql
-- finds values containing "50%"
WHERE discount_label LIKE '%50!%%' ESCAPE '!'
```

**Case sensitivity depends on the database**

| Database   | Default behaviour                                  |
| ---------- | -------------------------------------------------- |
| PostgreSQL | Case-sensitive (use`ILIKE` for case-insensitive) |
| MySQL      | Usually case-insensitive (depends on collation)    |
| SQL Server | Usually case-insensitive (depends on collation)    |
| SQLite     | Case-insensitive for ASCII letters                 |

Portable case-insensitive match:

```sql
WHERE LOWER(name) LIKE 'alice%'
```

> ⚡ A pattern starting with `%` (e.g. `'%son'`) can't use a regular index, so it's slow on large tables.

---

## BETWEEN

Filters values within a range. **Both ends are inclusive.**

```sql
SELECT name, salary
FROM employees
WHERE salary BETWEEN 50000 AND 65000;
-- same as: WHERE salary >= 50000 AND salary <= 65000
```

| name         | salary |
| ------------ | ------ |
| Bob Jones    | 52000  |
| Emma Davis   | 61000  |
| Frank Miller | 58000  |

**With dates**

```sql
SELECT name, hire_date
FROM employees
WHERE hire_date BETWEEN '2020-01-01' AND '2022-12-31';
```

| name        | hire_date  |
| ----------- | ---------- |
| Alice Smith | 2021-03-15 |
| David Brown | 2022-01-10 |
| Emma Davis  | 2020-05-25 |

**NOT BETWEEN**

```sql
SELECT name, salary
FROM employees
WHERE salary NOT BETWEEN 50000 AND 65000;
```

| name        | salary |
| ----------- | ------ |
| Alice Smith | 75000  |
| Carol White | 88000  |
| David Brown | 45000  |
| Grace Lee   | 49000  |

**Watch out for**

- **Order matters:** `BETWEEN 65000 AND 50000` returns nothing. Smaller value first.
- **Timestamps:** on a `DATETIME`/`TIMESTAMP` column, `'2022-12-31'` means midnight, so anything later that day is missed. Use a half-open range instead:

  ```sql
  WHERE created_at >= '2022-01-01'
    AND created_at <  '2023-01-01'
  ```

---

## IN

Checks whether a value matches **any value in a list**. A cleaner way to write multiple `OR`s.

```sql
SELECT name, city
FROM employees
WHERE city IN ('London', 'Leeds');
-- same as: WHERE city = 'London' OR city = 'Leeds'
```

| name         | city   |
| ------------ | ------ |
| Alice Smith  | London |
| Carol White  | London |
| Emma Davis   | London |
| Frank Miller | Leeds  |
| Henry Wilson | Leeds  |

**With a subquery**

```sql
SELECT name
FROM employees
WHERE department IN (
    SELECT department
    FROM departments
    WHERE budget > 100000
);
```

**NOT IN**

```sql
SELECT name, department
FROM employees
WHERE department NOT IN ('Engineering', 'Sales');
-- Bob Jones, Emma Davis, Grace Lee
```

> ⚠️ **The `NOT IN` + `NULL` trap:** if the list or subquery contains even one `NULL`, `NOT IN` returns **no rows at all**.
>
> ```sql
> WHERE salary NOT IN (45000, NULL)   -- returns nothing
> ```
>
> For subqueries, prefer `NOT EXISTS`, which handles `NULL` safely.

---

## NULL Handling

`NULL` means "unknown", so it can't be compared with `=` or `<>`.

```sql
-- ❌ always returns nothing
WHERE salary = NULL

-- ✅ correct
WHERE salary IS NULL       -- Henry Wilson
WHERE salary IS NOT NULL   -- everyone else
```

**Three-valued logic:** any comparison with `NULL` gives UNKNOWN, and `WHERE` drops UNKNOWN rows. That means these two queries together **don't** cover every row:

```sql
WHERE salary < 60000
WHERE NOT salary < 60000
-- Henry appears in neither
```

To treat `NULL` as a default value, use `COALESCE`:

```sql
WHERE COALESCE(salary, 0) < 60000   -- now includes Henry
```

---

## Common Gotchas

**1. Aggregates don't work in `WHERE`.** `WHERE` filters rows *before* grouping. Use `HAVING` for aggregates.

```sql
-- ❌ error
SELECT department, AVG(salary) FROM employees
WHERE AVG(salary) > 60000
GROUP BY department;

-- ✅
SELECT department, AVG(salary) FROM employees
GROUP BY department
HAVING AVG(salary) > 60000;
```

**2. `SELECT` aliases can't be used in `WHERE`** (in most databases), because of the logical processing order:

```
FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT
```

```sql
-- ❌ error in most databases
SELECT salary * 12 AS annual FROM employees WHERE annual > 600000;

-- ✅
SELECT salary * 12 AS annual FROM employees WHERE salary * 12 > 600000;
```

**3. Mixing `AND` / `OR` without parentheses.** See [Operator Precedence](#operator-precedence).

**4. `NOT IN` with `NULL`s.** See [IN](#in).

**5. `BETWEEN` on timestamps.** See [BETWEEN](#between).

**6. Single vs double quotes.** In standard SQL (and PostgreSQL), `'text'` is a string and `"name"` is a column/table identifier. Stick to single quotes for values.

**7. Wrapping columns in functions can kill index usage.**

```sql
-- ❌ can't use an index on hire_date
WHERE YEAR(hire_date) = 2021

-- ✅ index-friendly
WHERE hire_date >= '2021-01-01' AND hire_date < '2022-01-01'
```

---

## Cheat Sheet

| Operator                  | What it does                 | Example                            |
| ------------------------- | ---------------------------- | ---------------------------------- |
| `=`                     | Equal                        | `city = 'London'`                |
| `<>` / `!=`           | Not equal                    | `department <> 'HR'`             |
| `>` `<` `>=` `<=` | Comparisons                  | `salary >= 50000`                |
| `AND`                   | All conditions true          | `a = 1 AND b = 2`                |
| `OR`                    | At least one condition true  | `a = 1 OR b = 2`                 |
| `NOT`                   | Negates a condition          | `NOT city = 'Leeds'`             |
| `LIKE`                  | Pattern match (`%`, `_`) | `name LIKE 'A%'`                 |
| `BETWEEN`               | Inclusive range              | `salary BETWEEN 50000 AND 65000` |
| `IN`                    | Matches any value in a list  | `city IN ('London', 'Leeds')`    |
| `IS NULL`               | Value is`NULL`             | `salary IS NULL`                 |
| `IS NOT NULL`           | Value is not`NULL`         | `salary IS NOT NULL`             |

**Precedence:** `NOT` → `AND` → `OR`. When in doubt, use parentheses.
