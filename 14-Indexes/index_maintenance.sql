-- 1. Monitor Index Usage


-- list all indexes on a specific table
sp_helpindex 'Sales.Orders'

-- monitoring index usage
SELECT 
    tbl.name AS tableName,
    idx.name AS indexName,
    idx.type_desc AS indexType,
    idx.is_primary_key AS isPrimaryKey,
    idx.is_unique AS isUnique,
    idx.is_disabled AS isDisabled,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates,
    s.last_user_seek,
    s.last_user_scan
FROM sys.indexes AS idx
JOIN sys.tables AS tbl
ON idx.object_id = tbl.object_id
LEFT JOIN sys.dm_db_index_usage_stats AS s
ON s.object_id = idx.object_id AND s.index_id = idx.index_id
ORDER BY tbl.name, idx.name


-- dynamic management view (DMV)
-- provides real time insights into database performance and system health
SELECT * 
FROM sys.dm_db_index_usage_stats

SELECT * FROM Sales.Orders WHERE OrderStatus = 'Delivered'


-- 2. Monitor Missing Indexes
SELECT * FROM sys.dm_db_missing_index_details


-- 3. Monitor Duplicate Indexes


-- 4. Update Statistics


-- 5.Fragmentation, unused spaces in data pages, data pages are out of order
-- method 1: reorganize: defragments leaf nodes to keep them sorted: light operation
-- method 2: rebuild: recreates index from scratch: heavy operation