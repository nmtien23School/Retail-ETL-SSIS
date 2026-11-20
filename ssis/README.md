# SSIS — Kế hoạch package

Thư mục này chứa solution SSIS (`RetailETL.sln`) và các package `.dtsx`.
Thiết kế chi tiết xem [`../docs/ETL-Design.md`](../docs/ETL-Design.md).

## Cấu trúc solution đề xuất

```
ssis/
└── RetailETL/
    ├── RetailETL.sln
    └── RetailETL/
        ├── RetailETL.dtproj
        ├── Package.dtsx                 # Orchestrator: gọi các package con
        ├── Load_DimDate.dtsx
        ├── Load_DimCustomer.dtsx
        ├── Load_DimProduct.dtsx
        ├── Load_Fact_POS.dtsx
        ├── Load_Fact_Online.dtsx
        ├── Load_Fact_ERP.dtsx
        └── Load_Rejected.dtsx
```

## Connection Managers

| Tên | Loại | Trỏ tới |
|-----|------|---------|
| `POS_FF` | Flat File | `../data/POS.csv` |
| `Online_XLS` | Excel | `../data/Online.xlsx` |
| `ERP_SRC` | OLE DB | DB `RetailPlus_Legacy` |
| `DDS_DST` | OLE DB | DB `Retail_DDS` |

Nên tham số hóa đường dẫn (`Project.params`) thay vì hard-code.

## Gợi ý Control Flow

```
[Execute Load_DimDate] ──► [Execute Load_DimCustomer] ──► [Execute Load_DimProduct]
      ──► [Execute Load_Fact_POS] ──► [Execute Load_Fact_Online]
      ──► [Execute Load_Fact_ERP] ──► [Execute Load_Rejected]
```

Ghi chú:
- Mỗi package Fact dùng cùng khóa `TransactionNo`; dedup theo priority `ERP > POS > ONLINE`.
- Bật `OnError` / precedence constraint để dừng khi lỗi kết nối.
- Dùng `Row Count` + `Execute SQL Task` để log thống kê mỗi lần chạy.
