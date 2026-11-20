-- ==========================================================
-- SCRIPT VERIFY KẾT QUẢ ETL DATA WAREHOUSE (Retail_DDS)
-- ==========================================================
USE Retail_DDS;
GO

SET NOCOUNT ON;

PRINT '==========================================================';
PRINT '1. TỔNG SỐ DÒNG (ROW COUNT) TỪNG BẢNG TRONG DATA WAREHOUSE';
PRINT '==========================================================';
SELECT 'DimDate' AS TableName, COUNT(*) AS [TotalRows] FROM dbo.DimDate
UNION ALL SELECT 'DimCustomer', COUNT(*) FROM dbo.DimCustomer
UNION ALL SELECT 'DimProduct', COUNT(*) FROM dbo.DimProduct
UNION ALL SELECT 'FactSales', COUNT(*) FROM dbo.FactSales
UNION ALL SELECT 'ETL_RejectedRows', COUNT(*) FROM dbo.ETL_RejectedRows;

PRINT '';
PRINT '==========================================================';
PRINT '2. BÁO CÁO TỔNG HỢP DOANH THU FACTSALL THEO NGUỒN (SOURCE)';
PRINT '==========================================================';
SELECT 
    SourceSystem, 
    COUNT(*) AS [GiaoDichThanhCong], 
    SUM(Quantity) AS [TongSoLuong], 
    FORMAT(SUM(GrossAmount), 'N0') + ' VND' AS [DoanhThuChuaGiam], 
    FORMAT(SUM(DiscountAmount), 'N0') + ' VND' AS [TienGiamGia], 
    FORMAT(SUM(NetAmount), 'N0') + ' VND' AS [DoanhThuThucThu]
FROM dbo.FactSales
GROUP BY SourceSystem
ORDER BY SourceSystem;

PRINT '';
PRINT '==========================================================';
PRINT '3. THỐNG KÊ CHI TIẾT CÁC DÒNG BỊ LOẠI (ETL_RejectedRows)';
PRINT '==========================================================';
SELECT 
    SourceSystem, 
    RejectReason, 
    COUNT(*) AS [SoDongBiLoai]
FROM dbo.ETL_RejectedRows
GROUP BY SourceSystem, RejectReason
ORDER BY SourceSystem, [SoDongBiLoai] DESC;

PRINT '';
PRINT '==========================================================';
PRINT '4. MẪU DỮ LIỆU FACTSALL KẾT HỢP CHIỀU (DIMENSIONS)';
PRINT '==========================================================';
SELECT TOP 10
    fs.TransactionNo,
    fs.SourceSystem,
    dd.FullDate,
    dc.CustomerName,
    dp.ProductName,
    fs.Quantity,
    FORMAT(fs.UnitPrice, 'N0') + ' VND' AS UnitPrice,
    FORMAT(fs.NetAmount, 'N0') + ' VND' AS NetAmount
FROM dbo.FactSales fs
JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
JOIN dbo.DimCustomer dc ON fs.CustomerKey = dc.CustomerKey
JOIN dbo.DimProduct dp ON fs.ProductKey = dp.ProductKey
ORDER BY fs.DateKey, fs.TransactionNo;
GO
