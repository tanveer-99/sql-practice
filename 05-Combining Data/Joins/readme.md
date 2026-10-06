
# SQL Joins

A quick reference for combining tables in SQL: `INNER`, `LEFT`, `RIGHT`, `FULL`, the anti-join patterns, `CROSS`, and a multi-table join task.

---

## Table of Contents

- [Sample Data](#sample-data)
- [No Join](#no-join)
- [INNER JOIN](#inner-join)
- [LEFT JOIN](#left-join)
- [RIGHT JOIN](#right-join)
- [FULL JOIN](#full-join)
- [Anti Joins](#anti-joins)
- [Inner Join Without INNER JOIN](#inner-join-without-inner-join)
- [CROSS JOIN](#cross-join)
- [Task: Joining Multiple Tables](#task-joining-multiple-tables)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Sample Data

```sql
CREATE TABLE customers (
    id          INT PRIMARY KEY,
    first_name  VARCHAR(50),
    country     VARCHAR(50)
);

CREATE TABLE orders (
    order_id     INT PRIMARY KEY,
    customer_id  INT,
    sales        INT
);

INSERT INTO customers VALUES
(1, 'Jossef', 'Germany'),
(2, 'Martha', 'USA'),
(3, 'Georgi', 'Germany'),
(4, 'Martin', 'Germany'),
(5, 'Peter',  'USA');

INSERT INTO orders VALUES
(1001, 1, 10),
(1002, 2, 15),
(1003, 3, 20),
(1004, 6, 25);
```

**customers**

| id | first_name | country |
| -- | ---------- | ------- |
| 1  | Jossef     | Germany |
| 2  | Martha     | USA     |
| 3  | Georgi     | Germany |
| 4  | Martin     | Germany |
| 5  | Peter      | USA     |

**orders**

| order_id | customer_id | sales |
| -------- | ----------- | ----- |
| 1001     | 1           | 10    |
| 1002     | 2           | 15    |
| 1003     | 3           | 20    |
| 1004     | 6           | 25    |

Two things to notice, because every join below behaves differently around them:

- Martin (4) and Peter (5) have **no orders**.
- Order 1004 belongs to customer **6**, who **doesn't exist** in `customers`.

---

## No Join

Querying tables separately gives two independent result sets. Nothing is combined.

```sql
SELECT * FROM customers;
SELECT * FROM orders;
```

---

## INNER JOIN

Returns only rows with a **match in both tables**.

```sql
-- customers who have placed an order, with their orders
SELECT
    c.id,
    c.first_name,
    o.order_id,
    o.sales
FROM customers AS c
INNER JOIN orders AS o
    ON c.id = o.customer_id;
```

| id | first_name | order_id | sales |
| -- | ---------- | -------- | ----- |
| 1  | Jossef     | 1001     | 10    |
| 2  | Martha     | 1002     | 15    |
| 3  | Georgi     | 1003     | 20    |

Martin, Peter and order 1004 are dropped because they have no match.

---

## LEFT JOIN

Returns **all rows from the left table**, plus matching rows from the right. Where there's no match, right-side columns are `NULL`.

```sql
-- all customers, including those without orders
SELECT
    c.id,
    c.first_name,
    o.order_id,
    o.sales
FROM customers AS c
LEFT JOIN orders AS o
    ON c.id = o.customer_id;
```

| id | first_name | order_id | sales |
| -- | ---------- | -------- | ----- |
| 1  | Jossef     | 1001     | 10    |
| 2  | Martha     | 1002     | 15    |
| 3  | Georgi     | 1003     | 20    |
| 4  | Martin     | NULL     | NULL  |
| 5  | Peter      | NULL     | NULL  |

> The **order of tables matters** for `LEFT JOIN`. The table after `FROM` is the one you keep fully.

---

## RIGHT JOIN

Returns **all rows from the right table**, plus matching rows from the left. It's the mirror image of `LEFT JOIN`.

```sql
-- all orders, including orders without a matching customer
SELECT
    c.id,
    c.first_name,
    o.order_id,
    o.sales
FROM customers AS c
RIGHT JOIN orders AS o
    ON c.id = o.customer_id;
```

| id   | first_name | order_id | sales |
| ---- | ---------- | -------- | ----- |
| 1    | Jossef     | 1001     | 10    |
| 2    | Martha     | 1002     | 15    |
| 3    | Georgi     | 1003     | 20    |
| NULL | NULL       | 1004     | 25    |

**Same result using `LEFT JOIN`** (swap the table order). Most people prefer this because it keeps everything reading left to right:

```sql
SELECT
    c.id,
    c.first_name,
    o.order_id,
    o.sales
FROM orders AS o
LEFT JOIN customers AS c
    ON c.id = o.customer_id;
```

---

## FULL JOIN

Returns **all rows from both tables**. Matches are combined, and non-matches get `NULL` on the missing side.

```sql
SELECT *
FROM customers
FULL JOIN orders
    ON customers.id = orders.customer_id;
```

| id   | first_name | country | order_id | customer_id | sales |
| ---- | ---------- | ------- | -------- | ----------- | ----- |
| 1    | Jossef     | Germany | 1001     | 1           | 10    |
| 2    | Martha     | USA     | 1002     | 2           | 15    |
| 3    | Georgi     | Germany | 1003     | 3           | 20    |
| 4    | Martin     | Germany | NULL     | NULL        | NULL  |
| 5    | Peter      | USA     | NULL     | NULL        | NULL  |
| NULL | NULL       | NULL    | 1004     | 6           | 25    |

> ⚠️ `FULL JOIN` isn't supported in **MySQL** or **MariaDB**. Emulate it with `LEFT JOIN ... UNION ... RIGHT JOIN`.

---

## Anti Joins

Anti joins return rows that have **no match** in the other table. There's no `ANTI JOIN` keyword. You build them with an outer join plus a `WHERE ... IS NULL` filter.

### Left Anti Join

Rows in the left table with no match in the right.

```sql
-- customers who have not placed an order
SELECT *
FROM customers AS c
LEFT JOIN orders AS o
    ON c.id = o.customer_id
WHERE o.order_id IS NULL;
```

| id | first_name | country | order_id | customer_id | sales |
| -- | ---------- | ------- | -------- | ----------- | ----- |
| 4  | Martin     | Germany | NULL     | NULL        | NULL  |
| 5  | Peter      | USA     | NULL     | NULL        | NULL  |

### Right Anti Join

Rows in the right table with no match in the left.

```sql
-- orders without a matching customer
SELECT *
FROM customers AS c
RIGHT JOIN orders AS o
    ON c.id = o.customer_id
WHERE c.id IS NULL;
```

| id   | first_name | country | order_id | customer_id | sales |
| ---- | ---------- | ------- | -------- | ----------- | ----- |
| NULL | NULL       | NULL    | 1004     | 6           | 25    |

**Same result using `LEFT JOIN`:**

```sql
SELECT *
FROM orders AS o
LEFT JOIN customers AS c
    ON c.id = o.customer_id
WHERE c.id IS NULL;
```

### Full Anti Join

Rows that **don't match on either side**.

```sql
SELECT *
FROM customers AS c
FULL JOIN orders AS o
    ON c.id = o.customer_id
WHERE c.id IS NULL
   OR o.customer_id IS NULL;
```

| id   | first_name | country | order_id | customer_id | sales |
| ---- | ---------- | ------- | -------- | ----------- | ----- |
| 4    | Martin     | Germany | NULL     | NULL        | NULL  |
| 5    | Peter      | USA     | NULL     | NULL        | NULL  |
| NULL | NULL       | NULL    | 1004     | 6           | 25    |

> 💡 In the `WHERE` of an anti join, always check a column that is **never NULL when a match exists**, like a primary key or the join key. Checking a nullable column like `sales` would give wrong results.

---

## Inner Join Without INNER JOIN

You can get the same output as an `INNER JOIN` using a `LEFT JOIN` and filtering out the non-matches:

```sql
-- customers who placed an order, without using INNER JOIN
SELECT *
FROM customers AS c
LEFT JOIN orders AS o
    ON c.id = o.customer_id
WHERE o.order_id IS NOT NULL;
```

| id | first_name | country | order_id | customer_id | sales |
| -- | ---------- | ------- | -------- | ----------- | ----- |
| 1  | Jossef     | Germany | 1001     | 1           | 10    |
| 2  | Martha     | USA     | 1002     | 2           | 15    |
| 3  | Georgi     | Germany | 1003     | 3           | 20    |

It works, but a plain `INNER JOIN` is clearer and the optimiser handles it just as well, so use it unless you have a reason not to.

---

## CROSS JOIN

Returns **every possible combination** of rows from both tables (a Cartesian product). There's no `ON` condition.

```sql
SELECT *
FROM customers
CROSS JOIN orders;
```

Row count = rows in `customers` × rows in `orders` = 5 × 4 = **20 rows**.

First few rows:

| id  | first_name | country | order_id | customer_id | sales |
| --- | ---------- | ------- | -------- | ----------- | ----- |
| 1   | Jossef     | Germany | 1001     | 1           | 10    |
| 1   | Jossef     | Germany | 1002     | 2           | 15    |
| 1   | Jossef     | Germany | 1003     | 3           | 20    |
| 1   | Jossef     | Germany | 1004     | 6           | 25    |
| 2   | Martha     | USA     | 1001     | 1           | 10    |
| ... | ...        | ...     | ...      | ...         | ...   |

Useful for generating combinations (e.g. every product × every size), calendars, or test data. Be careful on big tables, since the output grows multiplicatively.

---

## Task: Joining Multiple Tables

**Using `SalesDB`, retrieve a list of all orders along with the related customer, product and employee details. For each order, display:** order id, customer's name, product name, sales, price, salesperson's name.

```sql
SELECT
    o.OrderID,
    o.Sales,
    c.FirstName AS CustomerFirstName,
    c.LastName  AS CustomerLastName,
    p.Product   AS ProductName,
    p.Price,
    e.FirstName AS EmployeeFirstName,
    e.LastName  AS EmployeeLastName
FROM Sales.Orders AS o
LEFT JOIN Sales.Customers AS c
    ON o.CustomerID = c.CustomerID
LEFT JOIN Sales.Products AS p
    ON o.ProductID = p.ProductID
LEFT JOIN Sales.Employees AS e
    ON o.SalesPersonID = e.EmployeeID;
```

**Why `LEFT JOIN` from `Orders`?** The brief says *all orders*. Starting from `Orders` and left joining everything else guarantees no order disappears, even if its customer, product or salesperson is missing or `NULL`. An `INNER JOIN` would silently drop those orders.

**Pattern for multi-table joins:** pick the table you want to keep every row of as the base (`FROM`), then chain a `JOIN` per lookup table, each with its own `ON`.

---

## Common Gotchas

**1. A `WHERE` filter on the right table turns a `LEFT JOIN` into an `INNER JOIN`.**

```sql
-- ❌ drops customers without orders (NULL > 10 is UNKNOWN)
SELECT c.first_name, o.sales
FROM customers AS c
LEFT JOIN orders AS o ON c.id = o.customer_id
WHERE o.sales > 10;

-- ✅ filter inside ON to keep unmatched customers
SELECT c.first_name, o.sales
FROM customers AS c
LEFT JOIN orders AS o
    ON c.id = o.customer_id
   AND o.sales > 10;
```

The only common exception is the anti-join pattern, where filtering for `IS NULL` is the whole point.

**2. Duplicates from one-to-many joins.** If a customer has 3 orders, they appear 3 times. That's correct, but it inflates `COUNT` and `SUM` if you aggregate on the customer side.

**3. `NULL` never matches `NULL` in a join.** If `customer_id` is `NULL` on an order, it won't match anything, not even a `NULL` in the other table.

**4. Forgetting the `ON` condition** (or using the old comma syntax with a missing `WHERE`) silently turns the join into a `CROSS JOIN`.

**5. Ambiguous column names.** If both tables have a column with the same name, qualify it (`c.id`, not `id`) or you'll get an error.

**6. Always alias and prefix columns.** `customers AS c` plus `c.first_name` makes multi-table queries readable.

---

## Cheat Sheet

| Join            | Returns                                    | Unmatched rows                                                |
| --------------- | ------------------------------------------ | ------------------------------------------------------------- |
| `INNER JOIN`  | Only matching rows                         | Dropped from both                                             |
| `LEFT JOIN`   | All left + matching right                  | Left kept, right is`NULL`                                   |
| `RIGHT JOIN`  | All right + matching left                  | Right kept, left is`NULL`                                   |
| `FULL JOIN`   | All rows from both                         | Kept, missing side is`NULL`                                 |
| Left anti join  | Left rows with**no** match           | `LEFT JOIN ... WHERE right_key IS NULL`                     |
| Right anti join | Right rows with**no** match          | `RIGHT JOIN ... WHERE left_key IS NULL`                     |
| Full anti join  | Rows with no match on**either** side | `FULL JOIN ... WHERE left_key IS NULL OR right_key IS NULL` |
| `CROSS JOIN`  | Every combination (A × B)                 | No`ON` condition                                            |

**Quick rule:** pick the join by asking *"which table's rows must I never lose?"* That table goes on the preserved side of an outer join.
