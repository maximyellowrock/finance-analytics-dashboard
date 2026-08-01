-- =============================================================
-- 03_create_silver_tables.sql
-- Silver layer: cleaned data with USD conversion, data-quality
-- logging, and lineage metadata (SourceFile / LoadDate)
-- =============================================================

CREATE SCHEMA silver;
GO

-- -------------------------------------------------------------
-- Data quality log: records real anomalies found in the source
-- data (not corrected, only documented for transparency)
-- -------------------------------------------------------------
CREATE TABLE silver.DataQualityLog (
    LogID           INT IDENTITY(1,1) PRIMARY KEY,
    TableName       VARCHAR(50),
    IssueType       VARCHAR(50),
    Description     VARCHAR(500),
    AffectedRows    INT,
    DetectedDate    DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO silver.DataQualityLog (TableName, IssueType, Description, AffectedRows)
VALUES (
    'GeneralLedger',
    'Balance Mismatch',
    'Total Debit does not equal Total Credit. GL is not a fully balanced double-entry ledger, likely due to synthetic/sample data. Flagged for awareness; not corrected at this stage.',
    2000
);
GO

-- -------------------------------------------------------------
-- Exchange rate reference table (static/illustrative rates --
-- documented as an assumption; a real project would use a
-- time-varying FactExchangeRate table instead)
-- -------------------------------------------------------------
CREATE TABLE silver.ExchangeRate (
    Currency        CHAR(3)         PRIMARY KEY,
    RateToUSD       DECIMAL(10,4)   NOT NULL
);
GO

ALTER TABLE silver.ExchangeRate
ADD CONSTRAINT CK_ExchangeRate_PositiveRate
CHECK (RateToUSD > 0);
GO

INSERT INTO silver.ExchangeRate (Currency, RateToUSD) VALUES
('USD', 1.0000),
('EUR', 1.0800),
('GBP', 1.2600),
('CAD', 0.7300),
('AUD', 0.6600);
GO

-- -------------------------------------------------------------
-- Silver tables: currency-converted, typed, with lineage columns
-- -------------------------------------------------------------
SELECT
    ap.APID,
    ap.Vendor,
    ap.InvoiceDate,
    ap.DueDate,
    ap.Amount,
    ap.Currency,
    CAST(ap.Amount * er.RateToUSD AS DECIMAL(18,2)) AS AmountUSD,
    er.RateToUSD AS AppliedRate,
    ap.Status_,
    ap.PaidDate,
    ap.Terms,
    ap.LoadDate,
    ap.SourceFile
INTO silver.AccountsPayable
FROM stg.AccountsPayable ap
JOIN silver.ExchangeRate er ON ap.Currency = er.Currency;
GO

SELECT
    ar.ARID,
    ar.Customer,
    ar.InvoiceDate,
    ar.DueDate,
    ar.Amount,
    ar.Currency,
    CAST(ar.Amount * er.RateToUSD AS DECIMAL(18,2)) AS AmountUSD,
    er.RateToUSD AS AppliedRate,
    ar.Status_,
    ar.ReceivedDate,
    ar.Terms,
    ar.LoadDate,
    ar.SourceFile
INTO silver.AccountsReceivable
FROM stg.AccountsReceivable ar
JOIN silver.ExchangeRate er ON ar.Currency = er.Currency;
GO

SELECT
    ec.ClaimID,
    ec.EmployeeID,
    ec.SubmitDate,
    ec.Category,
    ec.Description_,
    ec.Amount,
    ec.Currency,
    CAST(ec.Amount * er.RateToUSD AS DECIMAL(18,2)) AS AmountUSD,
    er.RateToUSD AS AppliedRate,
    ec.Status_,
    ec.ApprovedBy,
    ec.PayDate,
    ec.LoadDate,
    ec.SourceFile
INTO silver.ExpenseClaims
FROM stg.ExpenseClaims ec
JOIN silver.ExchangeRate er ON ec.Currency = er.Currency;
GO

SELECT
    gl.GLID,
    gl.TxnDate,
    gl.AccountNumber,
    gl.AccountName,
    gl.Debit,
    gl.Credit,
    CAST(gl.Debit * er.RateToUSD AS DECIMAL(18,2)) AS DebitUSD,
    CAST(gl.Credit * er.RateToUSD AS DECIMAL(18,2)) AS CreditUSD,
    er.RateToUSD AS AppliedRate,
    gl.Dept,
    gl.CostCenter,
    gl.Description,
    gl.Currency,
    gl.LoadDate,
    gl.SourceFile
INTO silver.GeneralLedger
FROM stg.GeneralLedger gl
JOIN silver.ExchangeRate er ON gl.Currency = er.Currency;
GO

-- BudgetForecast has no Currency column -- all figures are already USD,
-- so no exchange-rate join is required.
SELECT
    FiscalYear,
    Dept,
    Quarter_,
    BudgetUSD,
    ForecastUSD,
    ActualUSD,
    VarianceUSD,
    Notes,
    LoadDate,
    SourceFile
INTO silver.BudgetForecast
FROM stg.BudgetForecast;
GO
