-- =============================================================
-- 02_data_quality_checks.sql
-- Bronze layer profiling: row counts, nulls, duplicates,
-- date-range logic, and statistical outliers
-- =============================================================

-- 1. Row count check per table (compare against source Excel row counts)
SELECT 'AccountsPayable' AS TableName, COUNT(*) AS [RowCount] FROM stg.AccountsPayable
UNION ALL
SELECT 'AccountsReceivable', COUNT(*) FROM stg.AccountsReceivable
UNION ALL
SELECT 'BudgetForecast', COUNT(*) FROM stg.BudgetForecast
UNION ALL
SELECT 'ExpenseClaims', COUNT(*) FROM stg.ExpenseClaims
UNION ALL
SELECT 'GeneralLedger', COUNT(*) FROM stg.GeneralLedger;
GO

-- 2. Expected nulls (dates that are legitimately blank while unresolved)
SELECT
    (SELECT COUNT(*) FROM stg.AccountsPayable WHERE PaidDate IS NULL)      AS AP_NullPaidDate,
    (SELECT COUNT(*) FROM stg.AccountsReceivable WHERE ReceivedDate IS NULL) AS AR_NullReceivedDate,
    (SELECT COUNT(*) FROM stg.ExpenseClaims WHERE PayDate IS NULL)         AS EC_NullPayDate;
GO

-- 3. Unexpected nulls on required columns
SELECT 'AP-APID' AS Col, COUNT(*) AS NullCount FROM stg.AccountsPayable WHERE APID IS NULL
UNION ALL SELECT 'AP-Amount', COUNT(*) FROM stg.AccountsPayable WHERE Amount IS NULL
UNION ALL SELECT 'AP-Vendor', COUNT(*) FROM stg.AccountsPayable WHERE Vendor IS NULL
UNION ALL SELECT 'GL-Debit', COUNT(*) FROM stg.GeneralLedger WHERE Debit IS NULL
UNION ALL SELECT 'GL-Credit', COUNT(*) FROM stg.GeneralLedger WHERE Credit IS NULL;
GO

-- 4. Duplicate check (same combination of key business fields appearing
--    more than once suggests a duplicated record)
SELECT Vendor, InvoiceDate, Amount, COUNT(*) AS DuplicateCount
FROM stg.AccountsPayable
GROUP BY Vendor, InvoiceDate, Amount
HAVING COUNT(*) > 1;

SELECT Customer, InvoiceDate, Amount, COUNT(*) AS DuplicateCount
FROM stg.AccountsReceivable
GROUP BY Customer, InvoiceDate, Amount
HAVING COUNT(*) > 1;

SELECT FiscalYear, Dept, Quarter_, COUNT(*) AS DuplicateCount
FROM stg.BudgetForecast
GROUP BY FiscalYear, Dept, Quarter_
HAVING COUNT(*) > 1;

SELECT EmployeeID, SubmitDate, Amount, COUNT(*) AS DuplicateCount
FROM stg.ExpenseClaims
GROUP BY EmployeeID, SubmitDate, Amount
HAVING COUNT(*) > 1;

SELECT TxnDate, AccountNumber, Debit, Credit, Dept, CostCenter, COUNT(*) AS DuplicateCount
FROM stg.GeneralLedger
GROUP BY TxnDate, AccountNumber, Debit, Credit, Dept, CostCenter
HAVING COUNT(*) > 1;
GO

-- 5. Date-range logic check (due date should never precede invoice date)
SELECT *
FROM stg.AccountsPayable
WHERE DueDate < InvoiceDate;
GO

-- 6. Statistical outlier check (mean +/- 3 standard deviations)
SELECT *
FROM stg.AccountsPayable
WHERE Amount > (SELECT AVG(Amount) + 3*STDEV(Amount) FROM stg.AccountsPayable)
   OR Amount < (SELECT AVG(Amount) - 3*STDEV(Amount) FROM stg.AccountsPayable);

SELECT *
FROM stg.AccountsReceivable
WHERE Amount > (SELECT AVG(Amount) + 3*STDEV(Amount) FROM stg.AccountsReceivable)
   OR Amount < (SELECT AVG(Amount) - 3*STDEV(Amount) FROM stg.AccountsReceivable);

SELECT *
FROM stg.ExpenseClaims
WHERE Amount > (SELECT AVG(Amount) + 3*STDEV(Amount) FROM stg.ExpenseClaims)
   OR Amount < (SELECT AVG(Amount) - 3*STDEV(Amount) FROM stg.ExpenseClaims);

SELECT *
FROM stg.BudgetForecast
WHERE BudgetUSD   > (SELECT AVG(BudgetUSD) + 3*STDEV(BudgetUSD) FROM stg.BudgetForecast)
   OR BudgetUSD   < (SELECT AVG(BudgetUSD) - 3*STDEV(BudgetUSD) FROM stg.BudgetForecast)
   OR ForecastUSD > (SELECT AVG(ForecastUSD) + 3*STDEV(ForecastUSD) FROM stg.BudgetForecast)
   OR ForecastUSD < (SELECT AVG(ForecastUSD) - 3*STDEV(ForecastUSD) FROM stg.BudgetForecast)
   OR ActualUSD   > (SELECT AVG(ActualUSD) + 3*STDEV(ActualUSD) FROM stg.BudgetForecast)
   OR ActualUSD   < (SELECT AVG(ActualUSD) - 3*STDEV(ActualUSD) FROM stg.BudgetForecast);

SELECT *
FROM stg.GeneralLedger
WHERE Debit  > (SELECT AVG(Debit) + 3*STDEV(Debit) FROM stg.GeneralLedger)
   OR Debit  < (SELECT AVG(Debit) - 3*STDEV(Debit) FROM stg.GeneralLedger)
   OR Credit > (SELECT AVG(Credit) + 3*STDEV(Credit) FROM stg.GeneralLedger)
   OR Credit < (SELECT AVG(Credit) - 3*STDEV(Credit) FROM stg.GeneralLedger);
GO

-- Result of this profiling: no duplicates, no unexpected nulls, no
-- date-range violations, and no statistical outliers were found across
-- any of the five source tables. The one real anomaly found in this
-- project -- the General Ledger Debit/Credit imbalance -- was
-- discovered separately and is logged in silver.DataQualityLog
-- (see 03_create_silver_tables.sql).
