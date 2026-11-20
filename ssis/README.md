# SSIS Project

This directory contains the Visual Studio Integration Services project and its single entry-point package. The package coordinates the full refresh of the `Retail_DDS` warehouse.

## Project files

| File | Purpose |
|---|---|
| `BI_TA2.slnx` | Visual Studio solution |
| `BI_TA2.dtproj` | SSIS project; currently targets SQL Server 2025 |
| `Package.dtsx` | Control flow and data flows for the complete ETL run |
| `Project.params` | Project parameter file; currently contains no parameters |

## Control flow

The package runs tasks in this order:

1. **Clear DDS** — checks that both CSV paths are configured, clears fact, rejection, and dimension rows, then creates or truncates staging tables.
2. **Load DimDate** — inserts October 1–31, 2026.
3. **Load DimCustomer** and **Load DimProduct** — loads the ERP master tables.
4. **Load Fact ERP** — loads eligible ERP transactions first.
5. **Stage POS and Online Sources** — bulk loads `POS.csv` and `Online.csv` into warehouse staging tables.
6. **Load Fact POS** — inserts eligible POS transactions not already in `FactSales`.
7. **Load Fact Online** — inserts eligible online transactions not already in `FactSales`.
8. **Load Rejected and Duplicates** — records invalid source rows and valid lower-priority duplicates in `ETL_RejectedRows`.

The execution order implements the priority **ERP > POS > ONLINE**. The final logging task reads the stage tables after fact loading to identify rows that were rejected or skipped as duplicates.

## Connections and file configuration

| Name | Type | Default target |
|---|---|---|
| `DDS_DST` | OLE DB | `Retail_DDS` on `.\SQLEXPRESS` |
| `ERP_SRC` | OLE DB | `RetailPlus_Legacy` on `.\SQLEXPRESS` |

Both connections use Windows integrated security and the `MSOLEDBSQL.1` provider. Update the connection managers in `Package.dtsx` if your SQL Server instance or authentication setup differs.

The POS and online paths are stored in `Retail_DDS.dbo.ETL_FileConfig`; the package does not use Flat File or Excel connection managers. Configure absolute file paths by editing and running [`../sql/02_configure_file_paths.sql`](../sql/02_configure_file_paths.sql). SQL Server executes `BULK INSERT`, so its Database Engine identity must be able to read both files. The online package input is `data/Online.csv`; `data/Online.xlsx` is not read directly by SSIS.

## Running the package

1. Run [`../sql/00_source_ERP.sql`](../sql/00_source_ERP.sql) to create and seed the ERP database. Rerunning this script drops and recreates its sample tables.
2. Run [`../sql/01_target_RetailDDS.sql`](../sql/01_target_RetailDDS.sql) to create the warehouse database and missing tables.
3. Set and save the CSV paths in [`../sql/02_configure_file_paths.sql`](../sql/02_configure_file_paths.sql).
4. Open `BI_TA2.slnx` in a compatible Visual Studio installation, review both OLE DB connections, and execute `Package.dtsx`.

Each package run clears and reloads warehouse data. The file configuration table is retained across runs. If the path validation fails, the package stops before it deletes warehouse rows.

## Lookup and rejection behavior

Lookup components are configured to send unmatched rows to the no-match output instead of failing the data flow. The package's final SQL task examines `ERP_Sales` and the staged file inputs, then writes rejected transaction numbers and reasons to `ETL_RejectedRows`. Duplicate transactions are also logged there when an earlier, higher-priority source has already populated `FactSales`.

See the [root README](../README.md) for prerequisites, expected sample counts, data-quality rules, and troubleshooting guidance.
