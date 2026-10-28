-- stored procedure syntax
-- CREATE PROCEDURE ProcedureName AS
-- BEGIN
-- SQL STATEMENTS GO HERE
-- END

-- Step1: Write a query
-- For US Customers, find the total number of customers and the average score
SELECT 
    COUNT(*) AS total_customer,
    AVG(Score) AS avg_score
FROM Sales.Customers
WHERE Country= 'USA'

-- step2: turning the code into stored procedures
CREATE PROCEDURE GetCustomerSummary @Country NVARCHAR(50)
AS
BEGIN
SELECT 
    COUNT(*) AS total_customer,
    AVG(Score) AS avg_score
FROM Sales.Customers
WHERE Country= @Country
END

-- step3: execute the stored procedure
EXEC GetCustomerSummary


-- with parameters
ALTER PROCEDURE GetCustomerSummary @Country NVARCHAR(50) = 'USA' -- "USA" is the default value
AS
BEGIN

    BEGIN TRY

        DECLARE @total_Customer INT, @AVG_score FLOAT;

        -- =====================================================
        -- step 1: prepare and cleanup data
        -- =====================================================
        IF EXISTS 
        (
            SELECT 1 FROM Sales.Customers WHERE Score IS NULL AND Country = @Country
        )
        BEGIN
            PRINT('Updating Null scores to 0');
            UPDATE Sales.Customers
            SET Score = 0
            WHERE Score IS NULL AND Country = @Country
        END

        ELSE
        BEGIN
            PRINT('No NULL scores found')
        END;


        -- =====================================================
        -- Step 2: Generating Summary Report
        -- =====================================================


        -- calculate total customers and average score for specific country
        SELECT 
            @total_Customer = COUNT(*),
            @AVG_score = AVG(Score)
        FROM Sales.Customers
        WHERE Country= @Country;

        PRINT 'Total customers from ' + @Country + ' : ' + CAST(@total_Customer AS NVARCHAR);
        PRINT 'Average score from ' + @Country + ' : ' + CAST(@AVG_score AS NVARCHAR);

        -- calculate total number of orders and total number of sales for specific country
        SELECT
            COUNT(OrderID) AS total_orders,
            SUM(Sales) AS total_sales,
            1/0
        FROM Sales.Orders AS o
        JOIN Sales.Customers AS c
        ON c.CustomerID = o.CustomerID
        WHERE c.Country = @Country;

    END TRY
    BEGIN CATCH
        -- =====================================================
        -- Error Handling
        -- =====================================================
        PRINT('An error occured.');
        PRINT('Error Message: ' + ERROR_MESSAGE());
        PRINT('Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR));
        PRINT('Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR));
        PRINT('Error Procedure: ' + ERROR_PROCEDURE());
    END CATCH

END


-- execute
EXEC GetCustomerSummary @Country = 'Germany' -- returns Germany report
EXEC GetCustomerSummary -- returns USA(default) report


DROP PROCEDURE GetCustomerSummaryGermany

SELECT 


