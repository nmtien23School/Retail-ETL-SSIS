# TA2 — Retail ETL (SSIS)

Bài tập ETL: hợp nhất **3 nguồn dữ liệu bán hàng** về một **Data Warehouse** duy nhất
(`Retail_DDS`) bằng **SQL Server Integration Services (SSIS)**.

## Kiến trúc tổng quan

```
 POS.csv ───────────┐
 Online.xlsx ───────┼──►  SSIS (Extract → Validate → Transform → Dedup → Load)  ──►  Retail_DDS
 ERP.sql (legacy) ──┘                                                                    │
                                                              ┌──────────────────────────┴─────────────────────────┐
                                                              │ DimDate · DimCustomer · DimProduct · FactSales      │
                                                              │ ETL_RejectedRows (dòng lỗi + lý do)                 │
                                                              └────────────────────────────────────────────────────┘
```

## Cấu trúc thư mục

```
TA2/
├── README.md                      # Tổng quan dự án
├── .gitignore
├── .gitattributes
├── data/
│   ├── POS.csv                    # Nguồn POS (bán tại quầy)
│   └── Online.xlsx                # Nguồn Online (web)
├── sql/
│   ├── 00_source_ERP.sql          # Tạo & nạp DB nguồn legacy RetailPlus_Legacy
│   └── 01_target_RetailDDS.sql    # Tạo DB đích Retail_DDS (DDS)
├── ssis/
│   └── README.md                  # Kế hoạch package SSIS
└── docs/
    └── ETL-Design.md              # Mapping, business rules, xử lý lỗi & trùng
```

> **Lưu ý:** Các dòng dữ liệu lỗi trong bộ dữ liệu (ngày sai, số lượng `abc`, mã sản phẩm
> không tồn tại, giao dịch trùng, `Cancelled`...) là **cố ý** nhằm phục vụ mục đích luyện tập ETL.

## Nguồn dữ liệu

| Nguồn | Định dạng | Bảng/cột chính | SourceSystem |
|-------|-----------|----------------|--------------|
| POS | CSV | `TransID, SaleDate, CustID, SKU, Qty, Price, DiscountVND` | `POS` |
| Online | Excel | `OrderNo, OrderDate, BuyerCode, ItemCode, Quantity, UnitPrice, DiscountPct, Status` | `ONLINE` |
| ERP (legacy) | SQL Server | `ERP_Sales`, `CustomerMaster`, `ProductMaster`, `CustomerMap`, `ProductMap` | `ERP` |

## Đích (Retail_DDS)

- `DimDate` — chiều thời gian
- `DimCustomer` — chiều khách hàng
- `DimProduct` — chiều sản phẩm
- `FactSales` — bảng sự kiện bán hàng (UNIQUE `TransactionNo`)
- `ETL_RejectedRows` — lưu dòng bị loại kèm lý do

## Cách chạy

1. **Tạo DB nguồn ERP** (SSMS):
   ```sql
   :r sql/00_source_ERP.sql
   ```
2. **Tạo DB đích** (SSMS):
   ```sql
   :r sql/01_target_RetailDDS.sql
   ```
3. **Chạy SSIS**: mở solution trong `ssis/`, cấu hình Connection Manager
   (`POS_PATH`, `ONLINE_PATH`, `RetailPlus_Legacy`, `Retail_DDS`) rồi Execute package.

> Chi tiết mapping, quy tắc làm sạch dữ liệu và danh sách bản ghi lỗi:
> xem [`docs/ETL-Design.md`](docs/ETL-Design.md).
