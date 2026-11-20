-- Configure the absolute CSV paths used by Package.dtsx.
USE Retail_DDS;
GO

IF OBJECT_ID(N'dbo.ETL_FileConfig', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ETL_FileConfig (
        SourceSystem varchar(10) NOT NULL PRIMARY KEY,
        FilePath nvarchar(4000) NOT NULL,
        CONSTRAINT CK_ETL_FileConfig_SourceSystem
            CHECK (SourceSystem IN ('POS', 'ONLINE'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.ETL_FileConfig WHERE SourceSystem = 'POS')
    INSERT dbo.ETL_FileConfig (SourceSystem, FilePath) VALUES ('POS', N'');

IF NOT EXISTS (SELECT 1 FROM dbo.ETL_FileConfig WHERE SourceSystem = 'ONLINE')
    INSERT dbo.ETL_FileConfig (SourceSystem, FilePath) VALUES ('ONLINE', N'');
GO

-- Replace these sample values with absolute paths visible to the SQL Server Database Engine.
DECLARE @PosFilePath nvarchar(4000) =
    N'C:\path\to\Retail-ETL-SSIS\data\POS.csv';
DECLARE @OnlineFilePath nvarchar(4000) =
    N'C:\path\to\Retail-ETL-SSIS\data\Online.csv';

IF @PosFilePath LIKE N'C:\path\to\%'
   OR @OnlineFilePath LIKE N'C:\path\to\%'
BEGIN
    THROW 51001, 'Replace the sample CSV paths in this script before running it.', 1;
END;

UPDATE dbo.ETL_FileConfig
SET FilePath = @PosFilePath
WHERE SourceSystem = 'POS';

UPDATE dbo.ETL_FileConfig
SET FilePath = @OnlineFilePath
WHERE SourceSystem = 'ONLINE';
GO
