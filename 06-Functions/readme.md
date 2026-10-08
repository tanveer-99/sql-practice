
# SQL Functions: String, Number & Date

A quick reference for single-row functions in **T-SQL (SQL Server)**: string manipulation, numbers, and dates/times.

> Examples use SQL Server syntax. See [Dialect Differences](#dialect-differences) for PostgreSQL/MySQL equivalents.

---

## Table of Contents

- [Sample Data](#sample-data)
- [String Functions](#string-functions)
  - [CONCAT](#concat) · [LOWER / UPPER](#lower--upper) · [TRIM](#trim) · [REPLACE](#replace) · [LEN](#len) · [LEFT / RIGHT](#left--right) · [SUBSTRING](#substring)
- [Number Functions](#number-functions)
- [Date &amp; Time Functions](#date--time-functions)
  - [GETDATE](#getdate) · [Part Extraction](#part-extraction) · [Formatting](#formatting-and-casting) · [DATEADD](#dateadd) · [DATEDIFF](#datediff) · [Time Gap Analysis](#time-gap-analysis) · [ISDATE](#isdate)
- [Common Gotchas](#common-gotchas)
- [Dialect Differences](#dialect-differences)
- [Cheat Sheet](#cheat-sheet)

---

## Sample Data

```sql
CREATE SCHEMA Sales;
GO

CREATE TABLE customers (
    id          INT PRIMARY KEY,
    first_name  VARCHAR(50),
    country     VARCHAR(50)
);

INSERT INTO customers VALUES
(1, 'Jossef', 'Germany'),
(2, 'Martha', 'USA'),
(3, 'Georgi', 'Germany'),
(4, 'Martin', 'Germany'),
(5, 'Peter',  'USA');

CREATE TABLE Sales.Orders (
    OrderID       INT PRIMARY KEY,
    OrderDate     DATE,
    ShipDate      DATE,
    CreationTime  DATETIME2
);

INSERT INTO Sales.Orders VALUES
(1, '2025-01-01', '2025-01-05', '2025-01-01 12:34:56'),
(2, '2025-01-05', '2025-01-10', '2025-01-05 09:15:00'),
(3, '2025-02-10', '2025-02-12', '2025-02-10 15:30:45'),
(4, '2025-02-20', '2025-02-27', '2025-02-20 08:05:10'),
(5, '2025-03-15', '2025-03-18', '2025-03-15 18:45:30'),
(6, '2024-12-28', '2025-01-03', '2024-12-28 11:00:00');
```

---

# String Functions

## CONCAT

Joins values into one string.

```sql
-- list customers' first names together with their country in one column
SELECT
    first_name,
    country,
    CONCAT(first_name, ' ', country) AS name_country
FROM customers;
```

| first_name | country | name_country   |
| ---------- | ------- | -------------- |
| Jossef     | Germany | Jossef Germany |
| Martha     | USA     | Martha USA     |
| Georgi     | Germany | Georgi Germany |
| Martin     | Germany | Martin Germany |
| Peter      | USA     | Peter USA      |

> `CONCAT` treats `NULL` as an empty string. The `+` operator returns `NULL` if any part is `NULL`:
>
> ```sql
> SELECT 'a' + NULL;          -- NULL
> SELECT CONCAT('a', NULL);   -- 'a'
> ```

---

## LOWER / UPPER

```sql
SELECT
    first_name,
    LOWER(first_name) AS low_name,
    UPPER(first_name) AS up_name
FROM customers;
```

| first_name | low_name | up_name |
| ---------- | -------- | ------- |
| Jossef     | jossef   | JOSSEF  |
| Martha     | martha   | MARTHA  |
| Georgi     | georgi   | GEORGI  |
| Martin     | martin   | MARTIN  |
| Peter      | peter    | PETER   |

Handy for case-insensitive comparisons and for standardising data before joins or grouping.

---

## TRIM

Removes **leading and trailing spaces** (SQL Server 2017+). Also `LTRIM` / `RTRIM` for one side only.

```sql
-- find names with leading or trailing spaces
-- test data: ' Georgi' (leading space), 'Martin ' (trailing space), 'Peter'
WITH names AS (
    SELECT first_name
    FROM (VALUES (' Georgi'), ('Martin '), ('Peter')) AS t(first_name)
)
SELECT first_name
FROM names
WHERE first_name != TRIM(first_name);
```

| first_name  |
| ----------- |
| ` Georgi` |

> ⚠️ **`Martin ` is missed.** SQL Server ignores trailing spaces when comparing strings (`'Martin ' = 'Martin'` is true), so `!=` only catches **leading** spaces. Use `DATALENGTH` instead:
>
> ```sql
> WHERE DATALENGTH(first_name) <> DATALENGTH(TRIM(first_name))
> ```
>
> This returns both ` Georgi` and `Martin `.

---

## REPLACE

Replaces every occurrence of a substring.

```sql
-- remove dashes from a phone number
SELECT
    '123-456-789' AS phone,
    REPLACE('123-456-789', '-', '') AS clean_phone;
```

| phone       | clean_phone |
| ----------- | ----------- |
| 123-456-789 | 123456789   |

Replacing with `''` removes the character.

---

## LEN

Returns the number of characters.

```sql
SELECT first_name, LEN(first_name) AS len_name
FROM customers;
```

| first_name | len_name |
| ---------- | -------- |
| Jossef     | 6        |
| Martha     | 6        |
| Georgi     | 6        |
| Martin     | 6        |
| Peter      | 5        |

**Using `LEN` to detect extra spaces:**

```sql
SELECT
    first_name,
    LEN(first_name)                       AS len_name,
    LEN(TRIM(first_name))                 AS len_trim_name,
    LEN(first_name) - LEN(TRIM(first_name)) AS flag
FROM names;   -- the test data from the TRIM section
```

| first_name  | len_name | len_trim_name | flag        |
| ----------- | -------- | ------------- | ----------- |
| ` Georgi` | 7        | 6             | 1           |
| `Martin ` | 6        | 6             | **0** |
| `Peter`   | 5        | 5             | 0           |

> ⚠️ **`LEN` ignores trailing spaces** in SQL Server, so `Martin ` shows `flag = 0`. Use `DATALENGTH` (bytes) or `LEN(first_name + 'x') - 1` to count them. Note that `DATALENGTH` returns 2 bytes per character for `NVARCHAR`.

---

## LEFT / RIGHT

Extract characters from the start or end of a string.

```sql
SELECT
    first_name,
    LEFT(first_name, 2)  AS first_two,
    RIGHT(first_name, 2) AS last_two
FROM customers;
```

| first_name | first_two | last_two |
| ---------- | --------- | -------- |
| Jossef     | Jo        | ef       |
| Martha     | Ma        | ha       |
| Georgi     | Ge        | gi       |
| Martin     | Ma        | in       |
| Peter      | Pe        | er       |

---

## SUBSTRING

`SUBSTRING(value, start, length)`. Start is **1-based**.

```sql
-- first names without the first character
SELECT
    first_name,
    SUBSTRING(first_name, 2, LEN(first_name)) AS substring
FROM customers;
```

| first_name | substring |
| ---------- | --------- |
| Jossef     | ossef     |
| Martha     | artha     |
| Georgi     | eorgi     |
| Martin     | artin     |
| Peter      | eter      |

Passing `LEN(first_name)` as the length is a safe way to say "to the end". SQL Server doesn't error if the length runs past the end.

---

# Number Functions

```sql
SELECT
    3.543645                AS original,
    ROUND(3.543645, 2)      AS round_2,
    ROUND(3.543645, 1)      AS round_1,
    ROUND(3.543645, 0)      AS round_0;
```

| original | round_2  | round_1  | round_0  |
| -------- | -------- | -------- | -------- |
| 3.543645 | 3.540000 | 3.500000 | 4.000000 |

`ROUND(value, n)` rounds to `n` decimal places. A negative `n` rounds to the left of the decimal point (`ROUND(1234, -2)` gives `1200`). The trailing zeros are just the decimal type's scale, not extra precision.

```sql
SELECT -10 AS original, ABS(-10) AS absolute;
```

| original | absolute |
| -------- | -------- |
| -10      | 10       |

`ABS` returns the absolute value.

---

# Date & Time Functions

## GETDATE

Returns the current date and time **at the moment the query runs**.

```sql
SELECT
    OrderID,
    CreationTime,
    '2025-08-25' AS HardCoded,   -- fixed value, never changes
    GETDATE()    AS Today        -- changes every run
FROM Sales.Orders;
```

`GETDATE()` returns a `DATETIME` like `2025-08-25 14:03:21.540`. `SYSDATETIME()` is the higher-precision version.

---

## Part Extraction

| Function        | Returns                                              |
| --------------- | ---------------------------------------------------- |
| `DAY()`       | Day of the month (number)                            |
| `MONTH()`     | Month (number)                                       |
| `YEAR()`      | Year (number)                                        |
| `DATEPART()`  | A specific part as a**number**                 |
| `DATENAME()`  | A specific part as a**name** (string)          |
| `DATETRUNC()` | Truncates the date down to a part (SQL Server 2022+) |
| `EOMONTH()`   | Last day of the month                                |

```sql
SELECT
    OrderID,
    CreationTime,
    YEAR(CreationTime)                 AS year_num,
    MONTH(CreationTime)                AS month_num,
    DAY(CreationTime)                  AS day_num,
    DATEPART(hour, CreationTime)       AS hour_num,
    DATEPART(quarter, CreationTime)    AS quarter_num,
    DATEPART(weekday, CreationTime)    AS weekday_num,
    DATEPART(week, CreationTime)       AS week_num,
    DATENAME(month, CreationTime)      AS month_name,
    DATENAME(weekday, CreationTime)    AS weekday_name,
    DATENAME(quarter, CreationTime)    AS quarter_name,
    DATETRUNC(month, CreationTime)     AS month_trunc,
    DATETRUNC(hour, CreationTime)      AS hour_trunc,
    EOMONTH(CreationTime)              AS eomonth
FROM Sales.Orders;
```

Result for order 1 (`2025-01-01 12:34:56`, a Wednesday):

| Column       | Value                                            |
| ------------ | ------------------------------------------------ |
| year_num     | 2025                                             |
| month_num    | 1                                                |
| day_num      | 1                                                |
| hour_num     | 12                                               |
| quarter_num  | 1                                                |
| weekday_num  | 4*(Sunday = 1 with the default `DATEFIRST`)* |
| week_num     | 1                                                |
| month_name   | January                                          |
| weekday_name | Wednesday                                        |
| quarter_name | 1                                                |
| month_trunc  | 2025-01-01 00:00:00                              |
| hour_trunc   | 2025-01-01 12:00:00                              |
| eomonth      | 2025-01-31                                       |

### Grouping and filtering by date parts

```sql
-- how many orders were placed each year
SELECT
    YEAR(OrderDate) AS order_year,
    COUNT(*)        AS no_of_orders
FROM Sales.Orders
GROUP BY YEAR(OrderDate);
```

| order_year | no_of_orders |
| ---------- | ------------ |
| 2024       | 1            |
| 2025       | 5            |

```sql
-- how many orders were placed each month (by name)
SELECT
    DATENAME(month, OrderDate) AS order_month,
    COUNT(*)                   AS no_of_orders
FROM Sales.Orders
GROUP BY DATENAME(month, OrderDate);
```

| order_month | no_of_orders |
| ----------- | ------------ |
| December    | 1            |
| January     | 2            |
| February    | 2            |
| March       | 1            |

> Grouping by month **name** sorts alphabetically (if you sort at all) and merges the same month from different years. For reports, group by year and month number, then sort:
>
> ```sql
> SELECT
>     YEAR(OrderDate)            AS order_year,
>     MONTH(OrderDate)           AS order_month_num,
>     DATENAME(month, OrderDate) AS order_month,
>     COUNT(*)                   AS no_of_orders
> FROM Sales.Orders
> GROUP BY YEAR(OrderDate), MONTH(OrderDate), DATENAME(month, OrderDate)
> ORDER BY order_year, order_month_num;
> ```

```sql
-- all orders placed in February
SELECT *
FROM Sales.Orders
WHERE MONTH(OrderDate) = 2;
```

Returns orders 3 and 4.

> `MONTH(OrderDate) = 2` matches February of **every** year, and wrapping the column in a function stops indexes from being used. For one specific month, a range is faster:
>
> ```sql
> WHERE OrderDate >= '2025-02-01' AND OrderDate < '2025-03-01'
> ```

---

## Formatting and Casting

### Custom format with `FORMAT`

```sql
-- target format: Day Wed Jan Q1 2025 12:34:56 PM
SELECT
    OrderID,
    CreationTime,
    'Day ' + FORMAT(CreationTime, 'ddd MMM')
        + ' Q' + DATENAME(quarter, CreationTime) + ' '
        + FORMAT(CreationTime, 'yyyy hh:mm:ss tt') AS custom_format
FROM Sales.Orders;
```

| OrderID | custom_format                   |
| ------- | ------------------------------- |
| 1       | Day Wed Jan Q1 2025 12:34:56 PM |
| 2       | Day Sun Jan Q1 2025 09:15:00 AM |

### CAST vs CONVERT vs FORMAT

|               | `CAST`               | `CONVERT`                    | `FORMAT`                   |
| ------------- | ---------------------- | ------------------------------ | ---------------------------- |
| Syntax        | `CAST(expr AS type)` | `CONVERT(type, expr, style)` | `FORMAT(value, 'pattern')` |
| Standard SQL? | Yes (portable)         | No (SQL Server only)           | No (SQL Server only)         |
| Date styles   | No                     | Yes, via style codes           | Yes, via .NET patterns       |
| Returns       | The target type        | The target type                | `NVARCHAR`                 |
| Speed         | Fast                   | Fast                           | Slowest                      |

```sql
SELECT
    CAST('123' AS INT)                          AS cast_int,        -- 123
    CONVERT(VARCHAR(10), '2025-01-05', 23)      AS convert_iso,     -- 2025-01-05
    CONVERT(VARCHAR(10), CAST('2025-01-05' AS DATE), 103) AS convert_uk,  -- 05/01/2025
    FORMAT(CAST('2025-01-05' AS DATE), 'dd/MM/yyyy')      AS format_uk;   -- 05/01/2025
```

Rule of thumb: `CAST` for plain type changes, `CONVERT` when you need a date style code, `FORMAT` for custom display (not on large tables). `TRY_CAST` and `TRY_CONVERT` return `NULL` instead of an error when the conversion fails.

---

## DATEADD

Adds or subtracts an interval. `DATEADD(part, number, date)`. Use a **negative** number to subtract.

```sql
SELECT
    OrderID,
    OrderDate,
    DATEADD(day, -10, OrderDate)  AS ten_days_before,
    DATEADD(month, 3, OrderDate)  AS three_months_later,
    DATEADD(year, 2, OrderDate)   AS two_years_later
FROM Sales.Orders;
```

For order 1:

| OrderDate  | ten_days_before | three_months_later | two_years_later |
| ---------- | --------------- | ------------------ | --------------- |
| 2025-01-01 | 2024-12-22      | 2025-04-01         | 2027-01-01      |

---

## DATEDIFF

Difference between two dates. `DATEDIFF(part, start, end)`.

```sql
-- age of employees
SELECT
    EmployeeID,
    BirthDate,
    GETDATE() AS today,
    DATEDIFF(year, BirthDate, GETDATE()) AS age
FROM Sales.Employees;
```

> ⚠️ **`DATEDIFF` counts boundaries crossed, not full elapsed time.** `DATEDIFF(year, '1990-12-31', '2025-01-01')` returns `35`, but the person is only 34. For an accurate age, subtract 1 if the birthday hasn't happened yet this year:
>
> ```sql
> DATEDIFF(year, BirthDate, GETDATE())
>   - CASE WHEN DATEADD(year, DATEDIFF(year, BirthDate, GETDATE()), BirthDate) > GETDATE()
>          THEN 1 ELSE 0 END AS age
> ```

```sql
-- average shipping duration (days) for each month
SELECT
    DATENAME(month, OrderDate)                AS order_month,
    AVG(DATEDIFF(day, OrderDate, ShipDate))   AS avg_shipping_days
FROM Sales.Orders
GROUP BY DATENAME(month, OrderDate);
```

| order_month | avg_shipping_days |
| ----------- | ----------------- |
| December    | 6                 |
| January     | 4                 |
| February    | 4                 |
| March       | 3                 |

> ⚠️ `DATEDIFF` returns an `INT`, so `AVG` does **integer division** and truncates. January's real average is 4.5 (4 and 5 days), February's is 4.5 (2 and 7 days). Multiply by `1.0` to keep decimals:
>
> ```sql
> AVG(DATEDIFF(day, OrderDate, ShipDate) * 1.0)   -- January: 4.500000
> ```

---

## Time Gap Analysis

Use `LAG` to look at the previous row, then `DATEDIFF` for the gap.

```sql
-- days between each order and the previous order
SELECT
    OrderID,
    OrderDate AS current_order_date,
    LAG(OrderDate) OVER (ORDER BY OrderDate) AS previous_order_date,
    DATEDIFF(day, LAG(OrderDate) OVER (ORDER BY OrderDate), OrderDate) AS no_of_days
FROM Sales.Orders;
```

| OrderID | current_order_date | previous_order_date | no_of_days |
| ------- | ------------------ | ------------------- | ---------- |
| 6       | 2024-12-28         | NULL                | NULL       |
| 1       | 2025-01-01         | 2024-12-28          | 4          |
| 2       | 2025-01-05         | 2025-01-01          | 4          |
| 3       | 2025-02-10         | 2025-01-05          | 36         |
| 4       | 2025-02-20         | 2025-02-10          | 10         |
| 5       | 2025-03-15         | 2025-02-20          | 23         |

The first row has no previous order, so it's `NULL`.

---

## ISDATE

Checks whether a value can be read as a date. Returns `1` (valid) or `0` (not valid).

```sql
SELECT
    ISDATE('2025-08-20') AS valid,        -- 1
    ISDATE('hello')      AS not_a_date,   -- 0
    ISDATE('2025-13-45') AS bad_month;    -- 0
```

Use it to validate text before converting:

```sql
SELECT CASE WHEN ISDATE(date_text) = 1 THEN CAST(date_text AS DATE) END AS clean_date
FROM raw_data;
```

> `ISDATE` depends on the session's language and `DATEFORMAT` settings. `TRY_CAST(date_text AS DATE)`, which returns `NULL` for invalid input, is usually more reliable.

---

## Common Gotchas

1. **`LEN` and `=` ignore trailing spaces** in SQL Server, so space-detection with `LEN` or `!= TRIM()` only catches leading spaces. Use `DATALENGTH`.
2. **`+` vs `CONCAT` with `NULL`.** `+` returns `NULL`, `CONCAT` skips it.
3. **`DATEDIFF` counts boundaries, not elapsed time.** This affects ages and month/year differences.
4. **`AVG` on integers truncates.** Multiply by `1.0` or cast to decimal.
5. **Functions on columns in `WHERE`** (`YEAR(OrderDate) = 2025`) can't use indexes. Prefer date ranges.
6. **`FORMAT` is slow.** Fine for a few rows, avoid on millions.
7. **`DATEPART(weekday)` depends on `SET DATEFIRST`** and `DATENAME` depends on the session language.
8. **Version requirements:** `TRIM` needs SQL Server 2017+, `DATETRUNC` needs 2022+. On older versions, truncate to month with `DATEFROMPARTS(YEAR(d), MONTH(d), 1)`.
9. **Duplicate or misleading aliases.** Give every column a unique, accurate alias (`ten_days_before`, not `ten_days_later` for `-10`).

---

## Dialect Differences

| Task              | SQL Server              | PostgreSQL                                              | MySQL                            |
| ----------------- | ----------------------- | ------------------------------------------------------- | -------------------------------- |
| String length     | `LEN(s)`              | `LENGTH(s)`                                           | `CHAR_LENGTH(s)`               |
| Concatenate       | `CONCAT()` or `+`   | `CONCAT()` or `\|\|`                                  | `CONCAT()`                     |
| Current date/time | `GETDATE()`           | `NOW()`                                               | `NOW()`                        |
| Extract part      | `DATEPART(part, d)`   | `EXTRACT(part FROM d)`                                | `EXTRACT(part FROM d)`         |
| Add to date       | `DATEADD(day, 10, d)` | `d + INTERVAL '10 days'`                              | `DATE_ADD(d, INTERVAL 10 DAY)` |
| Days between      | `DATEDIFF(day, a, b)` | `b - a` (for dates)                                   | `DATEDIFF(b, a)`               |
| Truncate to month | `DATETRUNC(month, d)` | `DATE_TRUNC('month', d)`                              | `DATE_FORMAT(d, '%Y-%m-01')`   |
| Last day of month | `EOMONTH(d)`          | `DATE_TRUNC('month', d) + INTERVAL '1 month - 1 day'` | `LAST_DAY(d)`                  |

Note the **argument order** differences in the date-difference functions.

---

## Cheat Sheet

| Function                       | Purpose                                   | Example                              |
| ------------------------------ | ----------------------------------------- | ------------------------------------ |
| `CONCAT`                     | Join strings                              | `CONCAT(first_name, ' ', country)` |
| `LOWER` / `UPPER`          | Change case                               | `UPPER(first_name)`                |
| `TRIM`                       | Remove leading/trailing spaces            | `TRIM(first_name)`                 |
| `REPLACE`                    | Replace text                              | `REPLACE(phone, '-', '')`          |
| `LEN`                        | Character count (ignores trailing spaces) | `LEN(first_name)`                  |
| `LEFT` / `RIGHT`           | First/last n characters                   | `LEFT(first_name, 2)`              |
| `SUBSTRING`                  | Extract from position                     | `SUBSTRING(first_name, 2, 3)`      |
| `ROUND`                      | Round to n decimals                       | `ROUND(3.5436, 2)`                 |
| `ABS`                        | Absolute value                            | `ABS(-10)`                         |
| `GETDATE`                    | Current date and time                     | `GETDATE()`                        |
| `YEAR` / `MONTH` / `DAY` | Date parts as numbers                     | `YEAR(OrderDate)`                  |
| `DATEPART`                   | Any part as a number                      | `DATEPART(quarter, d)`             |
| `DATENAME`                   | Any part as a name                        | `DATENAME(month, d)`               |
| `DATETRUNC`                  | Truncate to a part                        | `DATETRUNC(month, d)`              |
| `EOMONTH`                    | Last day of month                         | `EOMONTH(d)`                       |
| `FORMAT`                     | Custom string format                      | `FORMAT(d, 'yyyy-MM')`             |
| `CAST` / `CONVERT`         | Change data type                          | `CAST(x AS DATE)`                  |
| `DATEADD`                    | Add/subtract interval                     | `DATEADD(month, 3, d)`             |
| `DATEDIFF`                   | Difference between dates                  | `DATEDIFF(day, a, b)`              |
| `ISDATE`                     | Is it a valid date? (1/0)                 | `ISDATE('2025-08-20')`             |
