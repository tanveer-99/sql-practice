/* these basic clauses can be used for any kind of queries */

-- ***coding order of the query***
-- SELECT DISTINCT TOP 2
--     col1, 
--     SUM(col2)
-- FROM table
-- WHERE col=10
-- GROUP BY col1
-- HAVING SUM(col2) > 30
-- ORDER BY col1 ASC

-- ***execution order of the query***
-- 1. FROM
-- 2. WHERE
-- 3. GROUP BY
-- 4. HAVING
-- 5. SELECT DISTINCT
-- 6. ORDER BY
-- 7. TOP

-- retrieve all customer data
SELECT * FROM customers

-- retrieve all orders data
SELECT * 
FROM orders

-- retrieve each customers name, country and score
SELECT first_name, country, score -- this will be the output table columns order
FROM customers

------- WHERE -----------

-- retrieve customers with a score not equal to 0
SELECT *
FROM customers
WHERE score != 0

-- retrieve customers from Germany
SELECT *
FROM customers
WHERE country='Germany'

------------ ORDER BY ---------------

-- retrieve all customers and sort the results by the highest score first
SELECT *
FROM customers
ORDER BY score DESC

-- retrieve all customers and sort the results by the lowest score first
SELECT *
FROM customers
ORDER BY score ASC -- ASC is defined by default, so no need to use ASC, but good practise to use

-- retrieve all customers and sort the results by the country and then by the highest score
SELECT *
FROM customers
ORDER BY country ASC, score DESC -- order of the nested orderby is very important here

------------ GROUP BY ---------------

/* ********* GROUP BY rule: ***********
All columns in the SELECT must be either aggregated or included in the GROUP BY
*/
-- find the total score for each country
SELECT            -- order 4
    country,    -- if i select first_name also, it will show me an error
    SUM(score) AS total_score    -- order 3, total_score only exists for this query
FROM customers    -- order 1  
GROUP BY country  -- order 2

-- find the total score and total number of customers for each country
SELECT 
    country,
    SUM(score) as total_score,
    COUNT(country) as num_of_customers
FROM customers
GROUP BY country

---------------- HAVING ---------------
/* WHERE is used before any aggregation or GROUP BY and HAVING is used after the aggregation and GROUP BY */
/* find the average score for each country 
 considering only customers with a score not equal to 0 
 and return only those countries with an average score greater than 430
*/
SELECT 
    country,
    AVG(score) AS avg_score
FROM customers
WHERE score!=0
GROUP BY country
HAVING AVG(score)>430

---------------- DISTINCT: Remove Duplicates ---------------
-- only the first one is returned as default, don't use DISTINCT unless it's necessary, because it can slow down the query
-- return unique list of countries
SELECT DISTINCT country
FROM customers

---------------- TOP: Limit Your Data ---------------
-- retrieve only 3 customers
SELECT TOP 3 *
FROM customers

-- retrieve the top 3 customers with the highest scores
SELECT TOP 3 *
FROM customers
ORDER BY score DESC

-- get the two most recent orders from the orders table
SELECT TOP 2 *
FROM orders
ORDER BY order_date DESC
