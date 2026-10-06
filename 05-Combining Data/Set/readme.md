
# SQL Set Operations

A quick reference for combining the results of two queries **vertically** (stacking rows): `UNION`, `UNION ALL`, `EXCEPT`, and `INTERSECT`.

Joins add more **columns** to each row. Set operations add or remove **rows**.

---

## Table of Contents

- [Sample Data](#sample-data)
- [Rules](#rules)
- [UNION](#union)
- [UNION ALL](#union-all)
- [EXCEPT](#except)
- [INTERSECT](#intersect)
- [Use Case: Combining Orders and OrdersArchive](#use-case-combining-orders-and-ordersarchive)
- [Use Case: Data Completeness Check](#use-case-data-completeness-check)
- [Common Gotchas](#common-gotchas)
- [Cheat Sheet](#cheat-sheet)

---

## Sample Data

```sql
CREATE TABLE Sales.Customers (
    CustomerID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    LastName   VARCHAR(50)
);

CREATE TABLE Sales.Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName  VARCHAR(50),
    LastName   VARCHAR(50)
);

INSERT INTO Sales.Customers VALUES
(1, 'Jossef', 'Goldberg'),
(2, 'Kevin',  'Brown'),
(3, 'Mary',   'Dury'),
(4, 'Mark',   'Schwarz'),
(5, 'Anna',   'Adams');

INSERT INTO Sales.Employees VALUES
(1, 'Frank',   'Lee'),
(2, 'Kevin',   'Brown'),
(3, 'Mary',    'Dury'),
(4, 'Michael', 'Ray'),
(5, 'Carol',   'Baker');
```

**Customers**

| FirstName | LastName |
| --------- | -------- |
| Jossef    | Goldberg |
| Kevin     | Brown    |
| Mary      | Dury     |
| Mark      | Schwarz  |
| Anna      | Adams    |

**Employees**

| FirstName | LastName |
| --------- | -------- |
| Frank     | Lee      |
| Kevin     | Brown    |
| Mary      | Dury     |
| Michael   | Ray      |
| Carol     | Baker    |

Kevin Brown and Mary Dury appear in **both** tables.

---

## Rules

For any set operation to work:

1. Both queries must return the **same number of columns**.
2. Corresponding columns must have **compatible data types**.
3. Columns are matched by **position**, not by name. The output column names come from the **first** query.
4. `ORDER BY` can only go at the **very end** and applies to the whole combined result.

---

## UNION

Combines the results of both queries and **removes duplicate rows**.

```sql
-- combine employees and customers into one list
SELECT FirstName, LastName FROM Sales.Customers
UNION
SELECT FirstName, LastName FROM Sales.Employees;
```

| FirstName | LastName |
| --------- | -------- |
| Anna      | Adams    |
| Carol     | Baker    |
| Frank     | Lee      |
| Jossef    | Goldberg |
| Kevin     | Brown    |
| Mark      | Schwarz  |
| Mary      | Dury     |
| Michael   | Ray      |

8 rows. Kevin and Mary appear once. (Row order isn't guaranteed without `ORDER BY`.)

The **order of the queries** doesn't matter for `UNION`. Swapping them gives the same rows. The **order of the columns** does matter (see [gotchas](#common-gotchas)).

`UNION` removes duplicates across the whole result, including duplicates within a single query.

---

## UNION ALL

Combines the results and **keeps every row**, including duplicates.

```sql
SELECT FirstName, LastName FROM Sales.Customers
UNION ALL
SELECT FirstName, LastName FROM Sales.Employees;
```

10 rows. Kevin Brown and Mary Dury each appear twice.

**Why use it:**

- **Faster than `UNION`**, because it skips the duplicate-removal step (a sort or hash over the whole result).
- If you know there are no duplicates (or you don't care), use `UNION ALL`.
- It's also handy for **finding duplicates and data quality issues**. Compare the row counts, or group the combined result:

```sql
SELECT FirstName, LastName, COUNT(*) AS cnt
FROM (
    SELECT FirstName, LastName FROM Sales.Customers
    UNION ALL
    SELECT FirstName, LastName FROM Sales.Employees
) AS combined
GROUP BY FirstName, LastName
HAVING COUNT(*) > 1;
```

| FirstName | LastName | cnt |
| --------- | -------- | --- |
| Kevin     | Brown    | 2   |
| Mary      | Dury     | 2   |

---

## EXCEPT

Returns **distinct rows from the first query that are not in the second**.

It's the only set operator where the **order of the queries changes the result**.

```sql
-- employees who are not customers
SELECT FirstName, LastName FROM Sales.Employees
EXCEPT
SELECT FirstName, LastName FROM Sales.Customers;
```

| FirstName | LastName |
| --------- | -------- |
| Carol     | Baker    |
| Frank     | Lee      |
| Michael   | Ray      |

```sql
-- customers who are not employees
SELECT FirstName, LastName FROM Sales.Customers
EXCEPT
SELECT FirstName, LastName FROM Sales.Employees;
```

| FirstName | LastName |
| --------- | -------- |
| Anna      | Adams    |
| Jossef    | Goldberg |
| Mark      | Schwarz  |

> `EXCEPT` is called `MINUS` in Oracle. In MySQL it's supported from 8.0.31.

---

## INTERSECT

Returns **only the distinct rows that appear in both queries**.

```sql
-- employees who are also customers
SELECT FirstName, LastName FROM Sales.Employees
INTERSECT
SELECT FirstName, LastName FROM Sales.Customers;
```

| FirstName | LastName |
| --------- | -------- |
| Kevin     | Brown    |
| Mary      | Dury     |

Like `UNION`, the order of the queries doesn't change the result.

---

## Use Case: Combining Orders and OrdersArchive

**Scenario:** order data is split across two tables (`Orders` and `OrdersArchive`). Combine everything into one report without duplicates.

```sql
SELECT
    'Orders' AS SourceTable,
    [OrderID], [ProductID], [CustomerID], [SalesPersonID],
    [OrderDate], [ShipDate], [OrderStatus], [ShipAddress],
    [BillAddress], [Quantity], [Sales], [CreationTime]
FROM Sales.Orders
UNION
SELECT
    'OrdersArchive' AS SourceTable,
    [OrderID], [ProductID], [CustomerID], [SalesPersonID],
    [OrderDate], [ShipDate], [OrderStatus], [ShipAddress],
    [BillAddress], [Quantity], [Sales], [CreationTime]
FROM Sales.OrdersArchive
ORDER BY OrderID;
```

> ⚠️ **This doesn't actually remove duplicates between the two tables.** The `SourceTable` column holds `'Orders'` in one query and `'OrdersArchive'` in the other, so no row from one table can ever equal a row from the other. `UNION` sees them all as distinct.

Pick the version that matches what you want:

```sql
-- Want the label and every row from both tables? Use UNION ALL (faster too)
... UNION ALL ...

-- Want true de-duplication? Drop the SourceTable column
SELECT [OrderID], [ProductID], ... FROM Sales.Orders
UNION
SELECT [OrderID], [ProductID], ... FROM Sales.OrdersArchive
ORDER BY OrderID;
```

`ORDER BY OrderID` works because it sits at the end and uses a column name from the first query.

---

## Use Case: Data Completeness Check

`EXCEPT` can compare two tables to detect discrepancies, for example after a **data migration** when you want to confirm everything made it to the destination.

Run it **both ways**:

```sql
-- rows in the source that are missing from the destination
SELECT * FROM source_table
EXCEPT
SELECT * FROM destination_table;

-- rows in the destination that aren't in the source
SELECT * FROM destination_table
EXCEPT
SELECT * FROM source_table;
```

If **both** queries return nothing, the two tables contain the same set of rows.

> ⚠️ `EXCEPT` compares **distinct rows**, so it ignores how many times a row appears. If the source has a row twice and the destination has it once, both queries still come back empty. Also compare row counts:
>
> ```sql
> SELECT
>     (SELECT COUNT(*) FROM source_table)      AS source_rows,
>     (SELECT COUNT(*) FROM destination_table) AS destination_rows;
> ```

Unlike joins, `EXCEPT` treats two `NULL`s as equal, which is what you want for this kind of check.

---

## Common Gotchas

**1. Column order matters (names don't).** Columns are matched by position. Swap them in one query and you silently mix up the data:

```sql
-- ❌ last names end up in the FirstName column for the second half
SELECT FirstName, LastName FROM Sales.Customers
UNION
SELECT LastName, FirstName FROM Sales.Employees;
```

Same column count and compatible types means SQL won't complain, so check the order yourself.

**2. `UNION` vs `UNION ALL`.** `UNION` quietly removes duplicates (and costs more). If you expected every row to be there, you want `UNION ALL`.

**3. Extra literal columns defeat de-duplication.** See the [OrdersArchive example](#use-case-combining-orders-and-ordersarchive).

**4. `ORDER BY` goes last only.** You can't put one inside each side of a `UNION`.

**5. Precedence.** In standard SQL, `INTERSECT` binds tighter than `UNION` and `EXCEPT`. When you chain several, use parentheses.

**6. `NULL`s are treated as equal** in set operations, but never match in a join. Results can differ if you reimplement a set operation with joins.

---

## Cheat Sheet

| Operator      | Returns                    | Duplicates | Query order matters? |
| ------------- | -------------------------- | ---------- | -------------------- |
| `UNION`     | All rows from both         | Removed    | No                   |
| `UNION ALL` | All rows from both         | Kept       | No                   |
| `EXCEPT`    | Rows in 1st but not in 2nd | Removed    | **Yes**        |
| `INTERSECT` | Rows in both               | Removed    | No                   |

**Quick rules:**

- Sure there are no duplicates, or want to keep them? `UNION ALL`.
- Need to find what's missing? `EXCEPT`, in both directions.
- Need what two sets share? `INTERSECT`.
