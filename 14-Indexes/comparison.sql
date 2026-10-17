-- comparing storage usage of different indexes
USE AdventureWorks2025
-- HEAP
SELECT *
INTO person_country_HP 
FROM Person.CountryRegion
-- RowStore
SELECT *
INTO person_country_RS
FROM Person.CountryRegion

CREATE CLUSTERED INDEX idx_person_country_RS_PK
ON person_country_RS (CountryRegionCode)


-- ColumnStore

SELECT *
INTO person_country_CS
FROM Person.CountryRegion

CREATE CLUSTERED COLUMNSTORE INDEX idx_personc_country_CS_PK
ON person_country_CS

