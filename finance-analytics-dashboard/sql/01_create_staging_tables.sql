-- =============================================================
-- 01_create_staging_tables.sql
-- Bronze layer: raw, untouched data loaded from source Excel files
-- =============================================================

CREATE SCHEMA stg;
GO

CREATE TABLE stg.AccountsPayable (
    APID          VARCHAR(20)     PRIMARY KEY,
    Vendor        VARCHAR(50),
    InvoiceDate   DATE,
    DueDate       DATE,
    Amount        DECIMAL(18,2),
    Currency      CHAR(3),
    Status_       VARCHAR(10),
    PaidDate      DATE            NULL,   -- NULL = not yet paid
    Terms         VARCHAR(10),
    LoadDate      DATETIME        DEFAULT GETDATE(),
    SourceFile    NVARCHAR(100)
);
GO

CREATE TABLE stg.AccountsReceivable (
    ARID          VARCHAR(10)     PRIMARY KEY,
    Customer      VARCHAR(50),
    InvoiceDate   DATE,
    DueDate       DATE,
    Amount        DECIMAL(18,2),
    Currency      CHAR(3),
    Status_       VARCHAR(10),
    ReceivedDate  DATE            NULL,   -- NULL = not yet received
    Terms         VARCHAR(10),
    LoadDate      DATETIME        DEFAULT GETDATE(),
    SourceFile    NVARCHAR(100)
);
GO

CREATE TABLE stg.BudgetForecast (
    FiscalYear    SMALLINT,
    Dept          VARCHAR(20),
    Quarter_      TINYINT,
    BudgetUSD     DECIMAL(18,2),
    ForecastUSD   DECIMAL(18,2),
    ActualUSD     DECIMAL(18,2),
    VarianceUSD   DECIMAL(18,2),
    Notes         VARCHAR(200)    NULL,
    LoadDate      DATETIME        DEFAULT GETDATE(),
    SourceFile    NVARCHAR(100)
);
GO

CREATE TABLE stg.ExpenseClaims (
    ClaimID       VARCHAR(10)     PRIMARY KEY,
    EmployeeID    VARCHAR(10),
    SubmitDate    DATE,
    Category      VARCHAR(20),
    Description_  VARCHAR(50),
    Amount        DECIMAL(18,2),
    Currency      CHAR(3),
    Status_       VARCHAR(15),
    ApprovedBy    VARCHAR(10),
    PayDate       DATE            NULL,   -- NULL = not yet paid
    LoadDate      DATETIME        DEFAULT GETDATE(),
    SourceFile    NVARCHAR(100)
);
GO

CREATE TABLE stg.GeneralLedger (
    GLID          VARCHAR(10)     PRIMARY KEY,
    TxnDate       DATE,
    AccountNumber INT,
    AccountName   VARCHAR(30),
    Debit         DECIMAL(18,2),
    Credit        DECIMAL(18,2),
    Dept          VARCHAR(20),
    CostCenter    VARCHAR(10),
    Description   VARCHAR(50),
    Currency      CHAR(3),
    LoadDate      DATETIME        DEFAULT GETDATE(),
    SourceFile    NVARCHAR(100)
);
GO

-- After running this script, load the source Excel files into these
-- tables using SQL Server Import and Export Wizard (Microsoft Access
-- Database Engine required for .xlsx import).
