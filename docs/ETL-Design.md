# ETL Design

This document describes the source-to-target mappings, validation rules, rejection handling, and duplicate policy implemented by `ssis/Package.dtsx`.

## 1. Execution flow

The package performs a full refresh in this order:

1. Validate POS and online paths in `dbo.ETL_FileConfig`, clear warehouse fact, rejection, and dimension rows, and prepare staging tables.
2. Load `DimDate` for October 1–31, 2026.
3. Load `DimCustomer` and `DimProduct` from the ERP master tables.
4. Load eligible ERP sales first.
5. Bulk load `data/POS.csv` and `data/Online.csv` into staging tables.
6. Load eligible POS sales, then eligible online sales, excluding transaction numbers already in `FactSales`.
7. Write invalid rows and lower-priority duplicates to `ETL_RejectedRows`.

The order establishes source priority `ERP > POS > ONLINE`. Unmatched SSIS Lookup rows are sent to no-match outputs instead of stopping the package. The final logging task uses staged records and ERP source rows to record excluded transactions.

## 2. Source-to-target mapping

### 2.1 POS (`data/POS.csv`, `SourceSystem = POS`)

| Target field | Source field | Transformation or rule |
|---|---|---|
| `TransactionNo` | `TransID` | Cast to `varchar(20)` |
| `DateKey` | `SaleDate` | Parse `dd/MM/yyyy`, then build `yyyyMMdd` integer key |
| `CustomerKey` | `CustID` | Lookup `DimCustomer.CustomerCode`; blank or unmatched values are rejected |
| `ProductKey` | `SKU` | Lookup `DimProduct.ProductCode`; unmatched values are rejected |
| `Quantity` | `Qty` | Convert to integer; must be greater than zero |
| `UnitPrice` | `Price` | Remove comma thousands separators and convert to decimal |
| `DiscountAmount` | `DiscountVND` | Convert to decimal; NULL or unparseable values default to zero in the fact source query |
| `GrossAmount` | — | `Quantity * UnitPrice` |
| `NetAmount` | — | `GrossAmount - DiscountAmount` |

### 2.2 Online (`data/Online.csv`, `SourceSystem = ONLINE`)

`data/Online.xlsx` is the editable workbook/reference. The SSIS package reads the CSV export at `data/Online.csv`.

| Target field | Source field | Transformation or rule |
|---|---|---|
| `TransactionNo` | `OrderNo` | Cast to `varchar(20)` |
| `DateKey` | `OrderDate` | Parse ISO date (`yyyy-MM-dd`), then build `yyyyMMdd` integer key |
| `CustomerKey` | `BuyerCode` | Resolve through `RetailPlus_Legacy.dbo.CustomerMap`, then look up `DimCustomer` |
| `ProductKey` | `ItemCode` | Resolve through `RetailPlus_Legacy.dbo.ProductMap`, then look up `DimProduct` |
| `Quantity` | `Quantity` | Convert to integer; must be greater than zero |
| `UnitPrice` | `UnitPrice` | Must be nonblank and convertible to decimal |
| `DiscountAmount` | `DiscountPct` | `ROUND(Quantity * UnitPrice * DiscountPct / 100, 2)` |
| `GrossAmount` | — | `Quantity * UnitPrice` |
| `NetAmount` | — | `GrossAmount - DiscountAmount` |
| — | `Status` | Only `Completed` rows are loaded |

The online status is trimmed and carriage returns are removed during comparison to handle CSV line endings.

### 2.3 ERP (`RetailPlus_Legacy`, `SourceSystem = ERP`)

| Target field | Source field | Transformation or rule |
|---|---|---|
| `TransactionNo` | `ERP_Sales.InvoiceID` | Cast to `varchar(20)` |
| `DateKey` | `ERP_Sales.InvoiceDate` | Use the date portion and build `yyyyMMdd` integer key |
| `CustomerKey` | `ERP_Sales.CustomerID` | Lookup `CustomerMaster` values loaded into `DimCustomer` |
| `ProductKey` | `ERP_Sales.ProductID` | Lookup `ProductMaster` values loaded into `DimProduct` |
| `Quantity` | `QtySold` | Convert to integer; must be greater than zero |
| `UnitPrice` | `SalePrice` | Copy decimal value |
| `DiscountAmount` | `DiscountMoney` | NULL defaults to zero |
| `GrossAmount` | — | `Quantity * UnitPrice` |
| `NetAmount` | — | `GrossAmount - DiscountAmount` |
| — | `Status` | Only `Completed` rows are loaded |

## 3. Validation and rejected sample rows

Rows that fail the sample package's status, quantity, date, required-code, or dimension-lookup checks are excluded from `FactSales` and logged in `ETL_RejectedRows`.

| Source | Transaction | Sample issue |
|---|---|---|
| POS | `T004` | Blank `CustID` |
| POS | `T007` | `Qty = abc` cannot be converted to a positive integer |
| POS | `T011` | `SKU = P999` has no product dimension match |
| POS | `T013` | `SaleDate = 32/10/2026` is invalid |
| ONLINE | `T013` | `UnitPrice` is blank |
| ONLINE | `T018` | `Quantity = -2` is not positive |
| ONLINE | `T021` | Status is `Cancelled` |
| ONLINE | `T024` | `ItemCode = WEB-P999` cannot be mapped to a product |
| ERP | `T024` | `QtySold = bad` cannot be converted to an integer |
| ERP | `T029` | Status is `Cancelled` |
| ERP | `T033` | `CustomerID = C999` is absent from the customer master |

There are 11 invalid or cancelled source rows: 4 POS, 4 online, and 3 ERP. The two separate `T024` source rows are independent records and each is rejected for its own source-specific issue.

## 4. Duplicate policy

`FactSales.TransactionNo` has a unique constraint. The package loads sources in priority order so the first valid source record wins: ERP, then POS, then online. A later source row with a transaction number already present in the fact table is excluded and logged as a duplicate.

The valid cross-source duplicate rows in the sample are:

| Transaction number | Sources | Retained source |
|---|---|---|
| `T012` | POS, ONLINE | POS |
| `T014`, `T015`, `T016` | POS, ONLINE | POS |
| `T022`, `T023`, `T025`, `T026` | ONLINE, ERP | ERP |

There are 8 lower-priority duplicate rows. Combined with 11 invalid or cancelled rows, the sample is expected to produce 19 rows in `ETL_RejectedRows`.

## 5. Expected sample totals

| Source | Input rows | Invalid or cancelled | Accepted before deduplication | Final fact rows |
|---|---:|---:|---:|---:|
| ERP | 16 | 3 | 13 | 13 |
| POS | 16 | 4 | 12 | 12 |
| ONLINE | 16 | 4 | 12 | 4 |
| **Total** | **48** | **11** | **37** | **29** |

The online accepted-before-deduplication count includes the 8 valid online rows that are later superseded by ERP or POS. These totals are derived from the checked-in sample data and have not been reported from an executed package run.

## 6. Warehouse schema and scope

- `DimDate` contains October 1–31, 2026 only.
- `FactSales` uses one globally unique transaction number as its business key and stores one fact row per transaction.
- `ETL_RejectedRows` stores a source system, transaction number, rejection reason, and timestamp.
- `ETL_FileConfig` stores absolute paths for the POS and online CSV files. The SQL Server Database Engine must be able to read those paths for `BULK INSERT`.
- Every package run is a full refresh. It clears fact, rejection, dimension, and stage rows before reloading them.
- `Online.csv` is the runtime source. Changes to `Online.xlsx` must be exported or synchronized to the CSV before a run.

If transactions can contain multiple product lines, or if transaction numbers are not globally unique across source systems, the fact table key and deduplication rule need to be redesigned for that business model.
