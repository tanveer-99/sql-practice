-- partition function: define the logic on how to divide your data into partitions, based on partition key like(column, region, ..)
-- filegroup: logical container of one or more data files to help organize partitions
-- data files: contains the actual data and stored physically in the database
-- partition scheme: connection between the data files and the partition


-- step1: create a partition function
CREATE PARTITION FUNCTION PartitionByYear(DATE)
AS RANGE LEFT FOR VALUES ('2023-12-31', '2024-12-31', '2025-12-31')

-- query: lists all existing partition function
SELECT
    name,
    function_id,
    type,
    type_desc,
    boundary_value_on_right
FROM sys.partition_functions

-- step2: create filegroups
ALTER DATABASE SalesDB ADD FILEGROUP FG_2023;
ALTER DATABASE SalesDB ADD FILEGROUP FG_2024;
ALTER DATABASE SalesDB ADD FILEGROUP FG_2025;
ALTER DATABASE SalesDB ADD FILEGROUP FG_2026;
-- query: lists all existing filegroups
SELECT *
FROM sys.filegroups
WHERE type='FG'

-- Step3: add .ndf to each file groups, create datafiles
ALTER DATABASE SalesDB ADD FILE 
(
    NAME = p_2023, -- logical name
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\DATA\p_2023.ndf'
) TO FILEGROUP FG_2023;
ALTER DATABASE SalesDB ADD FILE 
(
    NAME = p_2024, -- logical name
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\DATA\p_2024.ndf'
) TO FILEGROUP FG_2024;
ALTER DATABASE SalesDB ADD FILE 
(
    NAME = p_2025, -- logical name
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\DATA\p_2025.ndf'
) TO FILEGROUP FG_2025;
ALTER DATABASE SalesDB ADD FILE 
(
    NAME = p_2026, -- logical name
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\DATA\p_2026.ndf'
) TO FILEGROUP FG_2026;
-- query: check the filegroups
SELECT
    fg.name AS Filegroupname,
    mf.name AS LogicalFileName,
    mf.physical_name AS PhysicalFilePath,
    mf.size /128 AS SizeInMB
FROM sys.filegroups fg
JOIN sys.master_files mf ON fg.data_space_id = mf.data_space_id
WHERE mf.database_id = DB_ID('SalesDB')

-- step4: create partition scheme
CREATE PARTITION SCHEME SchemePartitionByYear 
AS PARTITION PartitionByYear 
TO (FG_2023, FG_2024, FG_2025, FG_2026)
-- query: lists all partition scheme
SELECT
    ps.name AS PartitionSchemeName,
    pf.name AS PartitionFunctionName,
    ds.destination_id AS PartitionNumber,
    fg.name AS FileGroupName
FROM sys.partition_schemes AS ps
JOIN sys.partition_functions AS pf ON ps.function_id = pf.function_id
JOIN sys.destination_data_spaces AS ds ON ps.data_space_id = ds.partition_scheme_id
JOIN sys.filegroups AS fg ON ds.data_space_id = fg.data_space_id

-- step5: create the partitioned table
CREATE TABLE Sales.Orders_Partitioned
(
    OrderID INT,
    OrderDate DATE,
    Sales INT
)
ON SchemePartitionByYear (OrderDate)

-- step6: Insert data into the partitioned table
INSERT INTO Sales.Orders_Partitioned VALUES (1,'2023-05-15', 100);
INSERT INTO Sales.Orders_Partitioned VALUES (2,'2024-05-15', 150);
INSERT INTO Sales.Orders_Partitioned VALUES (3,'2025-12-31', 990);
INSERT INTO Sales.Orders_Partitioned VALUES (4,'2026-05-15', 230);

SELECT * FROM Sales.Orders_Partitioned

-- query: see which partition the data is stored in
SELECT
    p.partition_number AS PartitionNumber,
    f.name AS PartitionFileGroup,
    p.rows AS NumberOfRows
FROM sys.partitions AS p
JOIN sys.destination_data_spaces dds ON p.partition_number = dds.destination_id
JOIN sys.filegroups AS f ON dds.data_space_id = f.data_space_id
wHERE OBJECT_NAME((p.object_id)) = 'Orders_Partitioned'