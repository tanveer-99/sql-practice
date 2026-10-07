-- concatenate first name and country into one column
-- show a list of customers' first names together with their country in one column
SELECT 
    first_name,
    country,
    CONCAT(first_name, ' ', country) AS name_country
FROM customers

-- Lower and Upper functions
-- convert the first name to lowercase
SELECT 
    first_name,
    country,
    CONCAT(first_name, ' ', country) AS name_country,
    LOWER(first_name) AS low_name
FROM customers
-- convert the first name to uppercase
SELECT 
    first_name,
    country,
    CONCAT(first_name, ' ', country) AS name_country,
    UPPER(first_name) AS up_name
FROM customers

-- TRIM
-- find customers whose first name contains leading or trailing spaces
SELECT 
    first_name
FROM customers
WHERE first_name != TRIM(first_name)
--
SELECT 
    first_name,
    LEN(first_name) AS len_name,
    LEN(TRIM(first_name)) AS len_trim_name,
    LEN(first_name) - LEN(TRIM(first_name)) flag
FROM customers

-- REPLACE
-- remove dashes from a phone number
SELECT 
    '123-456-789' AS phone,
    REPLACE('123-456-789', '-', '') AS clean_phone

-- LEN
-- calculate the length of each customer first name
SELECT first_name, LEN(first_name) AS len_name
FROM customers

-- LEFT and RIGHT
-- retrieve the first two characters of each first name
SELECT 
    first_name,
    LEFT(first_name, 2) AS first_two
FROM customers
-- retrieve the last two characters of each first name
SELECT 
    first_name,
    RIGHT(first_name, 2) AS first_two
FROM customers

-- SUBSTRING
-- retrieve a list of customers' first names removing the first character
SELECT 
    first_name,
    SUBSTRING(first_name, 2, LEN(first_name)) AS substring
FROM customers


---------- NUMBER Functions -----------
SELECT 
3.543645,
ROUND(3.543645, 2) AS round_1
SELECT 
-10,
ABS(-10)