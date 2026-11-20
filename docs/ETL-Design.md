# ETL Design — Retail ETL (SSIS)

Tài liệu mô tả thiết kế ETL: mapping nguồn → đích, quy tắc làm sạch, xử lý bản ghi lỗi
và chống trùng trước khi nạp vào `Retail_DDS`.

## 1. Luồng xử lý (pipeline)

```
Extract ──► Stage (raw) ──► Validate / Reject ──► Clean & Transform ──► Dedup ──► Load
                                  │                                          │
                                  └──► ETL_RejectedRows                      └──► FactSales
                                                          Dims: DimDate · DimCustomer · DimProduct
```

Thứ tự nạp đề xuất trong một package (hoặc nhiều package con):

1. `DimDate` — sinh đủ ngày trong khoảng dữ liệu (± biên).
2. `DimCustomer` / `DimProduct` — từ `CustomerMaster` / `ProductMaster`.
3. `FactSales` — sau khi đã validate + dedup.
4. `ETL_RejectedRows` — ghi song song mọi dòng bị loại (kèm lý do).

## 2. Mapping chi tiết

### 2.1 POS (`data/POS.csv`, SourceSystem = `POS`)

| Đích | Nguồn | Ghi chú |
|------|-------|---------|
| `TransactionNo` | `TransID` | |
| `DateKey` | `SaleDate` | Chuỗi `dd/MM/yyyy` → date |
| `CustomerKey` | `CustID` | Lookup `DimCustomer.CustomerCode`; rỗng ⇒ reject |
| `ProductKey` | `SKU` | Lookup `DimProduct.ProductCode`; không tồn tại ⇒ reject |
| `Quantity` | `Qty` | Ép int, phải `> 0` |
| `UnitPrice` | `Price` | Bỏ dấu `,` nghìn (`"100,000"` → `100000`) |
| `DiscountAmount` | `DiscountVND` | |
| `GrossAmount` | — | `Qty * UnitPrice` |
| `NetAmount` | — | `GrossAmount - DiscountAmount` |

### 2.2 Online (`data/Online.xlsx`, SourceSystem = `ONLINE`)

| Đích | Nguồn | Ghi chú |
|------|-------|---------|
| `TransactionNo` | `OrderNo` | |
| `DateKey` | `OrderDate` | Chuỗi `yyyy-MM-dd` → date |
| `CustomerKey` | `BuyerCode` | Qua `CustomerMap`: `WEB-Cxxx → Cxxx` → Lookup `DimCustomer` |
| `ProductKey` | `ItemCode` | Qua `ProductMap`: `WEB-Pxxx → Pxxx` → Lookup `DimProduct` |
| `Quantity` | `Quantity` | Phải `> 0` |
| `UnitPrice` | `UnitPrice` | Không được NULL |
| `DiscountAmount` | `DiscountPct` | `ROUND(GrossAmount * DiscountPct / 100, 0)` |
| `GrossAmount` | — | `Quantity * UnitPrice` |
| `NetAmount` | — | `GrossAmount - DiscountAmount` |
| — | `Status` | Chỉ nhận `Completed`; `Cancelled` ⇒ reject |

### 2.3 ERP (`RetailPlus_Legacy`, SourceSystem = `ERP`)

| Đích | Nguồn | Ghi chú |
|------|-------|---------|
| `TransactionNo` | `ERP_Sales.InvoiceID` | |
| `DateKey` | `ERP_Sales.InvoiceDate` | Lấy phần date |
| `CustomerKey` | `ERP_Sales.CustomerID` | Lookup `CustomerMaster`; không tồn tại ⇒ reject |
| `ProductKey` | `ERP_Sales.ProductID` | Lookup `ProductMaster`; không tồn tại ⇒ reject |
| `Quantity` | `QtySold` | Cột `varchar` → `TRY_CONVERT(int)`; lỗi ⇒ reject |
| `UnitPrice` | `SalePrice` | NULL ⇒ reject |
| `DiscountAmount` | `DiscountMoney` | |
| `GrossAmount` | — | `Quantity * SalePrice` |
| `NetAmount` | — | `GrossAmount - DiscountMoney` |
| — | `Status` | Chỉ nhận `Completed`; `Cancelled` ⇒ reject |

## 3. Quy tắc làm sạch & bản ghi lỗi dự kiến

Các dòng dưới đây được thiết kế để **bị loại** và ghi vào `ETL_RejectedRows`:

| Nguồn | TransactionNo | Lý do |
|-------|---------------|-------|
| POS | T004 | Thiếu `CustID` (customer rỗng) |
| POS | T007 | `Qty = 'abc'` — không ép được số nguyên |
| POS | T011 | `SKU = P999` — không có trong `ProductMaster` |
| POS | T013 | `SaleDate = 32/10/2026` — ngày không hợp lệ |
| ONLINE | T013 | `UnitPrice` rỗng (NULL) |
| ONLINE | T018 | `Quantity = -2` (≤ 0) |
| ONLINE | T021 | `Status = Cancelled` |
| ONLINE | T024 | `ItemCode = WEB-P999` — map/lookup thất bại |
| ERP | T024 | `QtySold = 'bad'` — không ép được int |
| ERP | T029 | `Status = Cancelled` |
| ERP | T033 | `CustomerID = C999` — không có trong `CustomerMaster` |

> Tổng: 12 dòng bị loại (4 POS · 4 Online · 3 ERP — trong đó T024 có ở cả Online và ERP).

## 4. Xử lý trùng (dedup) giữa các nguồn

Các nguồn dùng chung dải `TransactionNo` (`T011–T026`), nên **phải dedup sau khi validate**
trước khi ghi `FactSales` (ràng buộc `UQ_FactSales_TransactionNo`).

Các cặp trùng thực tế (sau khi loại dòng lỗi):

| TransactionNo | Nguồn trùng | Ghi chú |
|---------------|-------------|---------|
| T012 | POS, ONLINE | Giá trị discount khác nhau — cần chốt quy tắc ưu tiên |
| T014, T015, T016 | POS, ONLINE | Trùng khớp hoàn toàn |
| T022, T023, T025, T026 | ONLINE, ERP | Trùng khớp hoàn toàn |

**Quy tắc ưu tiên đề xuất: `ERP > POS > ONLINE`** (ERP là hệ thống gốc).
Cài đặt bằng `Lookup` trên `FactSales.TransactionNo` (hoặc bảng stage) + `Conditional Split`,
hoặc dùng `Sort` + `Remove Duplicates` theo khóa `(TransactionNo)` sau khi gán cột `Priority`.

Kết quả kỳ vọng: `12 + 12 + 13 = 37` dòng hợp lệ − `8` dòng trùng = **29 dòng `FactSales`**.

## 5. Sinh `DimDate`

Ví dụ sinh ngày cho khoảng dữ liệu (2026-10-01 → 2026-10-31):

```sql
WITH d AS (
    SELECT CAST('2026-10-01' AS date) AS dt
    UNION ALL
    SELECT DATEADD(day, 1, dt) FROM d WHERE dt < '2026-10-31'
)
INSERT dbo.DimDate (DateKey, FullDate, [Month], [Quarter], [Year])
SELECT CONVERT(int, FORMAT(dt, 'yyyyMMdd')), dt,
       MONTH(dt), DATEPART(quarter, dt), YEAR(dt)
FROM d
OPTION (MAXRECURSION 400);
```

## 6. Checklist triển khai SSIS

- [ ] Connection Managers: Flat File (POS), Excel (Online), OLE DB nguồn ERP, OLE DB đích DDS.
- [ ] `Data Flow` POS: Flat File Source → Derived Column (parse date, price, int) → Lookups → Reject Split.
- [ ] `Data Flow` Online: Excel Source → Derived (map mã qua Map tables) → Reject Split.
- [ ] `Data Flow` ERP: OLE DB Source (`ERP_Sales` join Master) → Derived (TRY_CONVERT) → Reject Split.
- [ ] Ghi `ETL_RejectedRows` với `SourceSystem`, `TransactionNo`, `RejectReason`.
- [ ] Dedup theo `TransactionNo` + priority trước khi insert `FactSales`.
- [ ] Log số dòng đọc / hợp lệ / loại / nạp (Row Count + OnError precedence constraint).
