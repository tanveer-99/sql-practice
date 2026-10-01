-- inserting data manually into a table

INSERT INTO customers (id, first_name, country, score)
VALUES
    (8, 'tan', 'UK', NULL),
    (9, 'vir', 'UK', 433)
-- columns and values must be in the same order
-- you can skip the columns name if you are inserting values for every column


-- inserting from another table
-- copy data from customers table into persons table
INSERT INTO persons (id, person_name, birth_date, phone)
SELECT 
    id,
    first_name,
    NULL,
    'unknown'
FROM customers

-- UPDATE
-- change the score of customer 6 to 0
UPDATE customers
SET score = 0
WHERE id = 6

-- change the score of customer 10 to 0 and update the country to UK
UPDATE customers
SET score = 0, country = 'UK'
WHERE id = 0

-- DELETE
-- delete all customers with an id greater than 5
DELETE FROM customers
WHERE id > 5

-- delete all the data from customers table
DELETE FROM customers
-- but a faster way is to use the 'TRUNCATE'