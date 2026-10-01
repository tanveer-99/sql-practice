
# SQL DML: INSERT, UPDATE, DELETE (T-SQL / SQL Server)

DML (Data Manipulation Language) commands change the **data** inside tables: adding rows, editing them, removing them. The table structure stays the same. Practised on the `customers` and `persons` tables.

**Files:** `dml-customers.sql` holds the annotated queries.

---

## Quick reference

| Command                    | What it does                        | Needs`WHERE`?                     |
| -------------------------- | ----------------------------------- | ----------------------------------- |
| `INSERT INTO ... VALUES` | Adds new rows by typing the values  | No                                  |
| `INSERT INTO ... SELECT` | Adds rows copied from another table | Optional, to pick which rows        |
| `UPDATE ... SET`         | Changes values in existing rows     | **Yes**, or every row changes |
| `DELETE FROM`            | Removes rows                        | **Yes**, or every row goes    |
| `TRUNCATE TABLE`         | Empties the whole table, fast       | Not allowed                         |

---

## Examples

### INSERT: add rows manually

```sql
INSERT INTO customers (id, first_name, country, score)
VALUES
    (8, 'tan', 'UK', NULL),
    (9, 'vir', 'UK', 433)
```

- Columns and values must be in the **same order**.
- You can skip the column list if you are inserting a value for **every** column, in the table's column order. Writing the list anyway is safer, because it still works if someone adds a column later.
- Several rows can go in one statement, separated by commas.
- `NULL` means "no value". It is not the same as `0` or an empty string.

### INSERT ... SELECT: copy from another table

```sql
-- copy data from customers into persons
INSERT INTO persons (id, person_name, birth_date, phone)
SELECT
    id,
    first_name,
    NULL,
    'unknown'
FROM customers
```

- The `SELECT` must return the same number of columns, in the same order, with compatible data types as the column list.
- Columns that don't exist in the source are filled with a fixed value (`NULL`, `'unknown'`). That is how `birth_date` and `phone` are handled here, since `customers` has neither.
- This is the pattern used constantly in data work to move data between tables.

### UPDATE: change existing rows

```sql
-- change the score of customer 6 to 0
UPDATE customers
SET score = 0
WHERE id = 6

-- change the score of customer 10 to 0 and the country to UK
UPDATE customers
SET score = 0, country = 'UK'
WHERE id = 10
```

Several columns can be changed in one `SET`, separated by commas.

### DELETE: remove rows

```sql
-- delete all customers with an id greater than 5
DELETE FROM customers
WHERE id > 5

-- delete ALL the data from the customers table
DELETE FROM customers
```

### TRUNCATE: the faster way to empty a table

```sql
TRUNCATE TABLE customers
```

`DELETE` without a `WHERE` removes rows one by one and logs each. `TRUNCATE` clears the table in one go, so it is much faster on large tables.

---

## Things to remember

- **Always write the `WHERE` on `UPDATE` and `DELETE`.** Without it, the command hits every row in the table. Habit: write the `WHERE` first, or run a `SELECT * FROM ... WHERE ...` with the same condition to see which rows will be affected.
- **Check the `WHERE` matches your intent.** `WHERE id = 0` updates nothing if no customer has id 0, and SQL Server won't complain. It just reports `0 rows affected`. Read that message after every `UPDATE` and `DELETE`.
- **`DELETE` vs `TRUNCATE` vs `DROP`:**
  | Command        | Removes                   | Table remains? | Can use`WHERE`? |
  | -------------- | ------------------------- | -------------- | ----------------- |
  | `DELETE`     | Chosen rows (or all)      | Yes            | Yes               |
  | `TRUNCATE`   | All rows                  | Yes            | No                |
  | `DROP TABLE` | Rows and the table itself | No             | No                |
- **`TRUNCATE` fails on a table that other tables reference through a foreign key**, even if it is empty. Use `DELETE` there.
- **`TRUNCATE` also resets identity (auto-number) columns back to the start. `DELETE` does not.**
- **Practice on copies.** Before destructive commands on a course table, make a copy so you can rebuild it from your setup script if you get it wrong.
- **DDL vs DML:** `CREATE`, `ALTER`, `DROP` change structure. `INSERT`, `UPDATE`, `DELETE` change data.

---

## Next up

Filtering operators, then joins, which combine rows from several tables.
