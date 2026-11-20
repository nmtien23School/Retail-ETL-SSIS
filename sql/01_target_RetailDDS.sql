-- SQL Server target schema: retail data warehouse
IF DB_ID('Retail_DDS') IS NULL
BEGIN
    CREATE DATABASE Retail_DDS;
END;
GO

USE Retail_DDS;
GO

IF OBJECT_ID(N'dbo.DimDate', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimDate (
        DateKey int NOT NULL PRIMARY KEY,
        FullDate date NOT NULL UNIQUE,
        [Month] tinyint NOT NULL,
        [Quarter] tinyint NOT NULL,
        [Year] smallint NOT NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.DimCustomer', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimCustomer (
        CustomerKey int IDENTITY(1,1) PRIMARY KEY,
        CustomerCode varchar(10) NOT NULL UNIQUE,
        CustomerName nvarchar(100) NOT NULL,
        City nvarchar(50) NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.DimProduct', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimProduct (
        ProductKey int IDENTITY(1,1) PRIMARY KEY,
        ProductCode varchar(10) NOT NULL UNIQUE,
        ProductName nvarchar(100) NOT NULL,
        Category nvarchar(50) NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.FactSales', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactSales (
        SalesKey bigint IDENTITY(1,1) PRIMARY KEY,
        TransactionNo varchar(20) NOT NULL,
        DateKey int NOT NULL REFERENCES dbo.DimDate(DateKey),
        CustomerKey int NOT NULL REFERENCES dbo.DimCustomer(CustomerKey),
        ProductKey int NOT NULL REFERENCES dbo.DimProduct(ProductKey),
        SourceSystem varchar(10) NOT NULL,
        Quantity int NOT NULL CHECK (Quantity > 0),
        UnitPrice decimal(18,2) NOT NULL CHECK (UnitPrice >= 0),
        GrossAmount decimal(18,2) NOT NULL,
        DiscountAmount decimal(18,2) NOT NULL,
        NetAmount decimal(18,2) NOT NULL,
        CONSTRAINT UQ_FactSales_TransactionNo UNIQUE (TransactionNo),
        CONSTRAINT CK_FactSales_Amounts CHECK (
            GrossAmount >= 0
            AND DiscountAmount >= 0
            AND DiscountAmount <= GrossAmount
            AND NetAmount = GrossAmount - DiscountAmount
        )
    );
END;
GO

IF OBJECT_ID(N'dbo.ETL_RejectedRows', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ETL_RejectedRows (
        RejectKey bigint IDENTITY(1,1) PRIMARY KEY,
        SourceSystem varchar(10) NOT NULL,
        TransactionNo varchar(20) NULL,
        RejectReason nvarchar(300) NOT NULL,
        RejectedAt datetime2 NOT NULL DEFAULT sysdatetime()
    );
END;
GO

-- Runtime file locations are kept outside the dimensional model.
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
