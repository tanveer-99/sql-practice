
# SQL DDL: CREATE, ALTER, DROP (T-SQL / SQL Server)

DDL (Data Definition Language) commands define and change the **structure** of a database: tables and columns, not the rows inside them. Practised by building, changing and deleting a `persons` table.

**Files:** `ddl-persons.sql` holds the annotated queries.

---

## Quick reference

| Command                         | What it does                                                | Example                                       |
| ------------------------------- | ----------------------------------------------------------- | --------------------------------------------- |
| `CREATE TABLE`                | Builds a new table with columns, data types and constraints | `CREATE TABLE persons (...)`                |
| `ALTER TABLE ... ADD`         | Adds a column to an existing table                          | `ALTER TABLE persons ADD email VARCHAR(50)` |
| `ALTER TABLE ... DROP COLUMN` | Removes a column (and its data)                             | `ALTER TABLE persons DROP COLUMN phone`     |
| `DROP TABLE`                  | Deletes the whole table: structure and data                 | `DROP TABLE persons`                        |

---

## Examples

### CREATE TABLE: build a table

```sql
-- create a table called persons with columns: id, person_name, birth_date, phone
CREATE TABLE persons (
    id          INT         NOT NULL,
    person_name VARCHAR(50) NOT NULL,
    birth_date  DATE,
    phone       VARCHAR(50) NOT NULL,
    CONSTRAINT pk_persons PRIMARY KEY (id)
)
```

What each part means:

| Part                                       | Meaning                                                                                      |
| ------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `INT`, `VARCHAR(50)`, `DATE`         | The data type of the column.`VARCHAR(50)` holds text up to 50 characters                   |
| `NOT NULL`                               | The column must always have a value. Leaving it out (like`birth_date`) allows empty values |
| `CONSTRAINT pk_persons PRIMARY KEY (id)` | Names the primary key, so every row is uniquely identified by`id`                          |

A primary key is automatically `NOT NULL` and unique. Naming the constraint (`pk_persons`) makes error messages and later changes easier to read than the auto-generated name.

### ALTER TABLE ... ADD: add a column

```sql
-- add a new column called email to the persons table
ALTER TABLE persons
ADD email VARCHAR(50) NOT NULL
```

In SQL Server the keyword is just `ADD`, without the word `COLUMN`. Other databases (PostgreSQL, MySQL) write `ADD COLUMN`.

### ALTER TABLE ... DROP COLUMN: remove a column

```sql
-- remove the phone column from the persons table
ALTER TABLE persons
DROP COLUMN phone
```

This permanently deletes the column and all the data in it.

### DROP TABLE: delete the table

```sql
-- delete the table persons from the database
DROP TABLE persons
```

This removes the table's structure **and** every row in it. There is no undo outside a backup.

---

## Things to remember

- **DDL changes structure, DML changes data.** `CREATE`, `ALTER`, `DROP` belong to DDL. `INSERT`, `UPDATE`, `DELETE` belong to DML, which is next.
- **Adding a `NOT NULL` column to a table that already has rows fails**, because existing rows would have no value for it. Fix it by adding a `DEFAULT`, or add the column as nullable, fill it, then tighten it:
  ```sql
  ALTER TABLE persons
  ADD email VARCHAR(50) NOT NULL DEFAULT 'unknown'
  ```

  The example above works here because the table was still empty.
- **Order matters in the file.** Run `CREATE` before `ALTER`, and `DROP TABLE` last, or the later statements have nothing to act on.
- **`DROP TABLE` on a missing table throws an error.** To make a script safe to re-run, guard it:
  ```sql
  DROP TABLE IF EXISTS persons
  ```

  (Supported in SQL Server 2016 and later.)
- **`DROP` vs `DELETE` vs `TRUNCATE`:** `DROP` removes the table itself, `DELETE` removes chosen rows, `TRUNCATE` empties all rows but keeps the table.
- After running these in VS Code or SSMS, refresh the Tables folder to see the change in the object tree.

---

## Next up

DML: `INSERT`, `UPDATE` and `DELETE`, which work on the rows inside tables like this one.
