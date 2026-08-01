-- =============================================================
-- 06_validation_queries.sql
-- Reconciliation checks: confirm no data loss across layers
-- =============================================================

-- 1. Bronze vs Silver row counts (should match exactly)
SELECT 'AccountsPayable' AS TableName,
       (SELECT COUNT(*) FROM stg.AccountsPayable) AS BronzeCount,
       (SELECT COUNT(*) FROM silver.AccountsPayable) AS SilverCount
UNION ALL
SELECT 'AccountsReceivable',
       (SELECT COUNT(*) FROM stg.AccountsReceivable),
       (SELECT COUNT(*) FROM silver.AccountsReceivable)
UNION ALL
SELECT 'BudgetForecast',
       (SELECT COUNT(*) FROM stg.BudgetForecast),
       (SELECT COUNT(*) FROM silver.BudgetForecast)
UNION ALL
SELECT 'ExpenseClaims',
       (SELECT COUNT(*) FROM stg.ExpenseClaims),
       (SELECT COUNT(*) FROM silver.ExpenseClaims)
UNION ALL
SELECT 'GeneralLedger',
       (SELECT COUNT(*) FROM stg.GeneralLedger),
       (SELECT COUNT(*) FROM silver.GeneralLedger);
GO

-- 2. Dimension table row counts
SELECT 'DimAccount' AS TableName, COUNT(*) AS [RowCount] FROM dw.DimAccount
UNION ALL SELECT 'DimCostCenter', COUNT(*) FROM dw.DimCostCenter
UNION ALL SELECT 'DimCurrency', COUNT(*) FROM dw.DimCurrency
UNION ALL SELECT 'DimCustomer', COUNT(*) FROM dw.DimCustomer
UNION ALL SELECT 'DimDate', COUNT(*) FROM dw.DimDate
UNION ALL SELECT 'DimDepartment', COUNT(*) FROM dw.DimDepartment
UNION ALL SELECT 'DimEmployee', COUNT(*) FROM dw.DimEmployee
UNION ALL SELECT 'DimExpenseCategory', COUNT(*) FROM dw.DimExpenseCategory
UNION ALL SELECT 'DimPaymentStatus', COUNT(*) FROM dw.DimPaymentStatus
UNION ALL SELECT 'DimVendor', COUNT(*) FROM dw.DimVendor;
GO

-- 3. Fact table row counts (should match the original source row
--    counts -- e.g. FactAccountsPayable = 800, FactGeneralLedger = 2000)
SELECT 'FactAccountsPayable' AS TableName, COUNT(*) AS [RowCount] FROM dw.FactAccountsPayable
UNION ALL SELECT 'FactAccountsReceivable', COUNT(*) FROM dw.FactAccountsReceivable
UNION ALL SELECT 'FactBudgetForecast', COUNT(*) FROM dw.FactBudgetForecast
UNION ALL SELECT 'FactExpenseClaims', COUNT(*) FROM dw.FactExpenseClaims
UNION ALL SELECT 'FactGeneralLedger', COUNT(*) FROM dw.FactGeneralLedger;
GO

-- 4. Data quality log contents (documented anomalies)
SELECT * FROM silver.DataQualityLog;
GO
