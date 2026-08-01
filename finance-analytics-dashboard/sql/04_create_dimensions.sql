-- =============================================================
-- 04_create_dimensions.sql
-- Gold layer (dw schema): dimension tables, star-schema design
-- =============================================================

CREATE SCHEMA dw;
GO

-- -------------------------------------------------------------
-- DimDate: central calendar dimension, one row per calendar day,
-- generated via a recursive CTE across the full date range used
-- anywhere in the source data. Used as a role-playing dimension
-- (multiple fact-table date columns reference this single table).
-- -------------------------------------------------------------
CREATE TABLE dw.DimDate (
    DateKey         INT          NOT NULL PRIMARY KEY,
    FullDate        DATE         NOT NULL UNIQUE,
    DayNumber       TINYINT      NOT NULL,
    DayName         VARCHAR(10)  NOT NULL,
    MonthNumber     TINYINT      NOT NULL,
    MonthName       VARCHAR(10)  NOT NULL,
    QuarterNumber   TINYINT      NOT NULL,
    YearNumber      SMALLINT     NOT NULL,
    FiscalQuarter   TINYINT      NOT NULL,
    FiscalYear      SMALLINT     NOT NULL,
    IsWeekend       BIT          NOT NULL,
    LoadDate        DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

;WITH AllDates AS
(
    SELECT CAST(TxnDate AS DATE) AS FullDate FROM silver.GeneralLedger
    UNION ALL SELECT CAST(InvoiceDate AS DATE) FROM silver.AccountsPayable
    UNION ALL SELECT CAST(DueDate AS DATE) FROM silver.AccountsPayable
    UNION ALL SELECT CAST(PaidDate AS DATE) FROM silver.AccountsPayable WHERE PaidDate IS NOT NULL
    UNION ALL SELECT CAST(InvoiceDate AS DATE) FROM silver.AccountsReceivable
    UNION ALL SELECT CAST(DueDate AS DATE) FROM silver.AccountsReceivable
    UNION ALL SELECT CAST(ReceivedDate AS DATE) FROM silver.AccountsReceivable WHERE ReceivedDate IS NOT NULL
    UNION ALL SELECT CAST(SubmitDate AS DATE) FROM silver.ExpenseClaims
    UNION ALL SELECT CAST(PayDate AS DATE) FROM silver.ExpenseClaims WHERE PayDate IS NOT NULL
    UNION ALL SELECT DATEFROMPARTS(FiscalYear, ((Quarter_ - 1) * 3) + 1, 1) FROM silver.BudgetForecast
),
DateBounds AS
(
    SELECT MIN(FullDate) AS StartDate, MAX(FullDate) AS EndDate FROM AllDates
),
DateSeries AS
(
    SELECT StartDate AS FullDate FROM DateBounds
    UNION ALL
    SELECT DATEADD(DAY, 1, ds.FullDate)
    FROM DateSeries ds
    CROSS JOIN DateBounds db
    WHERE ds.FullDate < db.EndDate
)
INSERT INTO dw.DimDate
(DateKey, FullDate, DayNumber, DayName, MonthNumber, MonthName,
 QuarterNumber, YearNumber, FiscalQuarter, FiscalYear, IsWeekend)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), FullDate, 112))  AS DateKey,
    FullDate,
    DAY(FullDate)                                  AS DayNumber,
    DATENAME(WEEKDAY, FullDate)                    AS DayName,
    MONTH(FullDate)                                AS MonthNumber,
    DATENAME(MONTH, FullDate)                       AS MonthName,
    DATEPART(QUARTER, FullDate)                     AS QuarterNumber,
    YEAR(FullDate)                                  AS YearNumber,
    DATEPART(QUARTER, FullDate)                     AS FiscalQuarter,
    YEAR(FullDate)                                  AS FiscalYear,
    CASE WHEN DATEDIFF(DAY, '19000101', FullDate) % 7 IN (5, 6) THEN 1 ELSE 0 END AS IsWeekend
FROM DateSeries
ORDER BY FullDate
OPTION (MAXRECURSION 0);
GO

-- In Power BI: DimDate is marked as a "Date table" (Table tools ->
-- Mark as date table -> FullDate) to enable DAX time-intelligence
-- functions such as DATESYTD.

-- -------------------------------------------------------------
-- DimCurrency
-- -------------------------------------------------------------
CREATE TABLE dw.DimCurrency (
    CurrencyKey     INT IDENTITY(1,1) PRIMARY KEY,
    CurrencyCode    CHAR(3),
    CurrencyName    VARCHAR(50),
    RateToUSD       DECIMAL(10,4),
    SourceFile      VARCHAR(100),
    LoadDate        DATETIME DEFAULT GETDATE()
);
GO

;WITH AllCurrencies AS
(
    SELECT TRIM(Currency) AS CurrencyCode, AppliedRate FROM silver.GeneralLedger
    UNION ALL SELECT TRIM(Currency), AppliedRate FROM silver.AccountsPayable
    UNION ALL SELECT TRIM(Currency), AppliedRate FROM silver.AccountsReceivable
    UNION ALL SELECT TRIM(Currency), AppliedRate FROM silver.ExpenseClaims
),
DistinctCurrencies AS
(
    SELECT
        CurrencyCode,
        CASE CurrencyCode
            WHEN 'AUD' THEN 'Australian Dollar'
            WHEN 'CAD' THEN 'Canadian Dollar'
            WHEN 'EUR' THEN 'Euro'
            WHEN 'GBP' THEN 'British Pound'
            WHEN 'USD' THEN 'US Dollar'
            ELSE 'Unknown Currency'
        END AS CurrencyName,
        MAX(AppliedRate) AS RateToUSD   -- profiling confirmed one rate per currency
    FROM AllCurrencies
    GROUP BY CurrencyCode
)
INSERT INTO dw.DimCurrency (CurrencyCode, CurrencyName, RateToUSD, SourceFile)
SELECT CurrencyCode, CurrencyName, RateToUSD, 'Multiple Silver Sources'
FROM DistinctCurrencies;
GO

-- -------------------------------------------------------------
-- DimVendor
-- -------------------------------------------------------------
CREATE TABLE dw.DimVendor (
    VendorKey       INT IDENTITY(1,1) PRIMARY KEY,
    VendorName      VARCHAR(100),
    SourceFile      VARCHAR(100),
    LoadDate        DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO dw.DimVendor (VendorName, SourceFile)
SELECT DISTINCT TRIM(Vendor), 'AccountsPayable'
FROM silver.AccountsPayable
WHERE Vendor IS NOT NULL;
GO

-- -------------------------------------------------------------
-- DimCustomer
-- -------------------------------------------------------------
CREATE TABLE dw.DimCustomer (
    CustomerKey     INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName    VARCHAR(100),
    SourceFile      VARCHAR(100),
    LoadDate        DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO dw.DimCustomer (CustomerName, SourceFile)
SELECT DISTINCT TRIM(Customer), 'AccountsReceivable'
FROM silver.AccountsReceivable
WHERE Customer IS NOT NULL;
GO

-- -------------------------------------------------------------
-- DimEmployee
-- -------------------------------------------------------------
CREATE TABLE dw.DimEmployee (
    EmployeeKey     INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID      VARCHAR(20),
    SourceFile      VARCHAR(100),
    LoadDate        DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO dw.DimEmployee (EmployeeID, SourceFile)
SELECT DISTINCT TRIM(EmployeeID), 'ExpenseClaims'
FROM silver.ExpenseClaims
WHERE EmployeeID IS NOT NULL;
GO

-- -------------------------------------------------------------
-- DimDepartment (conformed dimension -- shared by GeneralLedger
-- and BudgetForecast, so both sources are unioned together)
-- -------------------------------------------------------------
CREATE TABLE dw.DimDepartment (
    DepartmentKey   INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentName  VARCHAR(50),
    SourceFile      VARCHAR(100),
    LoadDate        DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO dw.DimDepartment (DepartmentName, SourceFile)
SELECT DISTINCT TRIM(Dept), 'GeneralLedger+BudgetForecast'
FROM (
    SELECT Dept FROM silver.GeneralLedger
    UNION
    SELECT Dept FROM silver.BudgetForecast
) AS AllDept
WHERE Dept IS NOT NULL;
GO

-- -------------------------------------------------------------
-- DimAccount
-- -------------------------------------------------------------
CREATE TABLE dw.DimAccount (
    AccountKey      INT IDENTITY(1,1) PRIMARY KEY,
    AccountNumber   INT,
    AccountName     VARCHAR(50),
    SourceFile      VARCHAR(100),
    LoadDate        DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO dw.DimAccount (AccountNumber, AccountName, SourceFile)
SELECT DISTINCT AccountNumber, AccountName, 'GeneralLedger'
FROM silver.GeneralLedger
WHERE AccountNumber IS NOT NULL;
GO

-- -------------------------------------------------------------
-- DimExpenseCategory
-- -------------------------------------------------------------
CREATE TABLE dw.DimExpenseCategory (
    ExpenseCategoryKey INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName        VARCHAR(50),
    SourceFile           VARCHAR(100),
    LoadDate             DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO dw.DimExpenseCategory (CategoryName, SourceFile)
SELECT DISTINCT Category, 'ExpenseClaims'
FROM silver.ExpenseClaims
WHERE Category IS NOT NULL;
GO

-- -------------------------------------------------------------
-- DimCostCenter
-- -------------------------------------------------------------
CREATE TABLE dw.DimCostCenter (
    CostCenterKey   INT IDENTITY(1,1) PRIMARY KEY,
    CostCenterCode  VARCHAR(20),
    SourceFile      VARCHAR(100),
    LoadDate        DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO dw.DimCostCenter (CostCenterCode, SourceFile)
SELECT DISTINCT CostCenter, 'GeneralLedger'
FROM silver.GeneralLedger
WHERE CostCenter IS NOT NULL;
GO

-- -------------------------------------------------------------
-- DimPaymentStatus (composite: ProcessType + StatusName, because
-- the same status label e.g. "Paid" carries different meaning
-- depending on which process it comes from)
-- -------------------------------------------------------------
CREATE TABLE dw.DimPaymentStatus (
    PaymentStatusKey INT IDENTITY(1,1) PRIMARY KEY,
    ProcessType       VARCHAR(30),
    StatusName        VARCHAR(30),
    SourceFile        VARCHAR(100),
    LoadDate          DATETIME DEFAULT GETDATE(),
    CONSTRAINT UQ_PaymentStatus UNIQUE (ProcessType, StatusName)
);
GO

INSERT INTO dw.DimPaymentStatus (ProcessType, StatusName, SourceFile)
SELECT DISTINCT 'AccountsPayable', Status_, 'AccountsPayable'
FROM silver.AccountsPayable
WHERE Status_ IS NOT NULL

UNION ALL

SELECT DISTINCT 'AccountsReceivable', Status_, 'AccountsReceivable'
FROM silver.AccountsReceivable
WHERE Status_ IS NOT NULL

UNION ALL

SELECT DISTINCT 'ExpenseClaims', Status_, 'ExpenseClaims'
FROM silver.ExpenseClaims
WHERE Status_ IS NOT NULL;
GO
