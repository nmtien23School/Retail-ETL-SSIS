-- SQL Server: nguồn ERP và bảng danh mục, chạy trong SSMS
IF DB_ID('RetailPlus_Legacy') IS NULL CREATE DATABASE RetailPlus_Legacy;
GO
USE RetailPlus_Legacy;
GO
DROP TABLE IF EXISTS dbo.ERP_Sales; 
DROP TABLE IF EXISTS dbo.CustomerMaster; 
DROP TABLE IF EXISTS dbo.ProductMaster; 
DROP TABLE IF EXISTS dbo.CustomerMap; 
DROP TABLE IF EXISTS dbo.ProductMap;
CREATE TABLE dbo.ERP_Sales(
InvoiceID varchar(20), 
InvoiceDate datetime2, 
CustomerID varchar(20), 
ProductID varchar(20), 
QtySold varchar(20), 
SalePrice decimal(18,2) NULL, 
DiscountMoney decimal(18,2), 
Status varchar(20));

CREATE TABLE dbo.CustomerMaster(
CustomerCode varchar(10) PRIMARY KEY, 
CustomerName nvarchar(100), 
City nvarchar(50));

CREATE TABLE dbo.ProductMaster(
ProductCode varchar(10) PRIMARY KEY, 
ProductName nvarchar(100), 
Category nvarchar(50));

CREATE TABLE dbo.CustomerMap(
SourceCode varchar(20) PRIMARY KEY, 
CustomerCode varchar(10));

CREATE TABLE dbo.ProductMap(
SourceCode varchar(20) PRIMARY KEY, 
ProductCode varchar(10));

INSERT dbo.CustomerMaster VALUES('C001',N'Khách hàng 1',N'Hà Nội');
INSERT dbo.CustomerMaster VALUES('C002',N'Khách hàng 2',N'TP.HCM');
INSERT dbo.CustomerMaster VALUES('C003',N'Khách hàng 3',N'Đà Nẵng');
INSERT dbo.CustomerMaster VALUES('C004',N'Khách hàng 4',N'Cần Thơ');
INSERT dbo.CustomerMaster VALUES('C005',N'Khách hàng 5',N'Hải Phòng');
INSERT dbo.ProductMaster VALUES('P001',N'Sản phẩm 1',N'Điện tử');
INSERT dbo.ProductMaster VALUES('P002',N'Sản phẩm 2',N'Gia dụng');
INSERT dbo.ProductMaster VALUES('P003',N'Sản phẩm 3',N'Thực phẩm');
INSERT dbo.ProductMaster VALUES('P004',N'Sản phẩm 4',N'Văn phòng');
INSERT dbo.CustomerMap VALUES('WEB-C001','C001');
INSERT dbo.CustomerMap VALUES('WEB-C002','C002');
INSERT dbo.CustomerMap VALUES('WEB-C003','C003');
INSERT dbo.CustomerMap VALUES('WEB-C004','C004');
INSERT dbo.CustomerMap VALUES('WEB-C005','C005');
INSERT dbo.ProductMap VALUES('WEB-P001','P001');
INSERT dbo.ProductMap VALUES('WEB-P002','P002');
INSERT dbo.ProductMap VALUES('WEB-P003','P003');
INSERT dbo.ProductMap VALUES('WEB-P004','P004');
INSERT dbo.ERP_Sales VALUES('T021','2026-10-02 09:30:00','C001','P001','1',100000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T022','2026-10-03 09:30:00','C002','P002','2',200000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T023','2026-10-04 09:30:00','C003','P003','3',75000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T024','2026-10-05 09:30:00','C004','P004','bad',150000,10000,'Completed');
INSERT dbo.ERP_Sales VALUES('T025','2026-10-06 09:30:00','C005','P001','2',100000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T026','2026-10-07 09:30:00','C001','P002','3',200000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T027','2026-10-08 09:30:00','C002','P003','1',75000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T028','2026-10-09 09:30:00','C003','P004','2',150000,10000,'Completed');
INSERT dbo.ERP_Sales VALUES('T029','2026-10-10 09:30:00','C004','P001','3',100000,0,'Cancelled');
INSERT dbo.ERP_Sales VALUES('T030','2026-10-11 09:30:00','C005','P002','1',200000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T031','2026-10-12 09:30:00','C001','P003','2',75000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T032','2026-10-13 09:30:00','C002','P004','3',150000,10000,'Completed');
INSERT dbo.ERP_Sales VALUES('T033','2026-10-14 09:30:00','C999','P001','1',100000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T034','2026-10-15 09:30:00','C004','P002','2',200000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T035','2026-10-16 09:30:00','C005','P003','3',75000,0,'Completed');
INSERT dbo.ERP_Sales VALUES('T036','2026-10-17 09:30:00','C001','P004','1',150000,10000,'Completed');
