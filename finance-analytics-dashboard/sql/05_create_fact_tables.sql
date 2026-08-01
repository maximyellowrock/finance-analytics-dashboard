-- =============================================================
-- 05_create_fact_tables.sql
-- Gold layer (dw schema): fact tables, one per source process,
-- linking to conformed and role-playing dimensions via
-- surrogate keys
-- =============================================================

-- -------------------------------------------------------------
-- FactAccountsPayable
-- -------------------------------------------------------------
CREATE TABLE dw.FactAccountsPayable (
    AccountsPayableKey INT IDENTITY(1,1) PRIMARY KEY,
    APID               VARCHAR(50) NOT NULL UNIQUE,
    VendorKey          INT NOT NULL,
    InvoiceDateKey     INT NOT NULL,
    DueDateKey         INT NOT NULL,
    PaidDateKey        INT NULL,
    CurrencyKey        INT NOT NULL,
    PaymentStatusKey   INT NOT NULL,
    Amount             DECIMAL(18,2) NOT NULL,
    AppliedRate        DECIMAL(10,4) NOT NULL,
    AmountUSD          DECIMAL(18,2) NOT NULL,
    Terms              VARCHAR(50) NULL,
    SourceFile         VARCHAR(255) NULL,
    LoadDate            DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_FactAP_Vendor        FOREIGN KEY (VendorKey)        REFERENCES dw.DimVendor(VendorKey),
    CONSTRAINT FK_FactAP_InvoiceDate   FOREIGN KEY (InvoiceDateKey)   REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactAP_DueDate       FOREIGN KEY (DueDateKey)       REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactAP_PaidDate      FOREIGN KEY (PaidDateKey)      REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactAP_Currency      FOREIGN KEY (CurrencyKey)      REFERENCES dw.DimCurrency(CurrencyKey),
    CONSTRAINT FK_FactAP_PaymentStatus FOREIGN KEY (PaymentStatusKey) REFERENCES dw.DimPaymentStatus(PaymentStatusKey)
);
GO

INSERT INTO dw.FactAccountsPayable
(APID, VendorKey, InvoiceDateKey, DueDateKey, PaidDateKey, CurrencyKey, PaymentStatusKey, Amount, AppliedRate, AmountUSD, Terms, SourceFile)
SELECT
    ap.APID,
    v.VendorKey,
    d1.DateKey,
    d2.DateKey,
    d3.DateKey,
    c.CurrencyKey,
    ps.PaymentStatusKey,
    ap.Amount,
    ap.AppliedRate,
    ap.AmountUSD,
    ap.Terms,
    'AccountsPayable'
FROM silver.AccountsPayable ap
JOIN dw.DimVendor v         ON ap.Vendor = v.VendorName
JOIN dw.DimDate d1          ON ap.InvoiceDate = d1.FullDate
JOIN dw.DimDate d2          ON ap.DueDate = d2.FullDate
LEFT JOIN dw.DimDate d3     ON ap.PaidDate = d3.FullDate      -- LEFT JOIN: PaidDate can be NULL
JOIN dw.DimCurrency c       ON ap.Currency = c.CurrencyCode
JOIN dw.DimPaymentStatus ps ON ap.Status_ = ps.StatusName AND ps.ProcessType = 'AccountsPayable';
GO

-- -------------------------------------------------------------
-- FactAccountsReceivable
-- -------------------------------------------------------------
CREATE TABLE dw.FactAccountsReceivable (
    FactAccountsReceivableKey INT IDENTITY(1,1) PRIMARY KEY,
    ARID                      VARCHAR(50) NOT NULL UNIQUE,
    CustomerKey               INT NOT NULL,
    InvoiceDateKey            INT NOT NULL,
    DueDateKey                INT NOT NULL,
    ReceivedDateKey           INT NULL,
    CurrencyKey               INT NOT NULL,
    PaymentStatusKey          INT NOT NULL,
    Amount                    DECIMAL(18,2) NOT NULL,
    AppliedRate               DECIMAL(10,4) NOT NULL,
    AmountUSD                 DECIMAL(18,2) NOT NULL,
    Terms                     VARCHAR(50) NULL,
    SourceFile                VARCHAR(255) NULL,
    LoadDate                  DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_FactAR_Customer      FOREIGN KEY (CustomerKey)      REFERENCES dw.DimCustomer(CustomerKey),
    CONSTRAINT FK_FactAR_InvoiceDate   FOREIGN KEY (InvoiceDateKey)   REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactAR_DueDate       FOREIGN KEY (DueDateKey)       REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactAR_ReceivedDate  FOREIGN KEY (ReceivedDateKey)  REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactAR_Currency      FOREIGN KEY (CurrencyKey)      REFERENCES dw.DimCurrency(CurrencyKey),
    CONSTRAINT FK_FactAR_Status        FOREIGN KEY (PaymentStatusKey) REFERENCES dw.DimPaymentStatus(PaymentStatusKey)
);
GO

INSERT INTO dw.FactAccountsReceivable
(ARID, CustomerKey, InvoiceDateKey, DueDateKey, ReceivedDateKey, CurrencyKey, PaymentStatusKey, Amount, AppliedRate, AmountUSD, Terms, SourceFile)
SELECT
    ar.ARID,
    cuk.CustomerKey,
    d1.DateKey,
    d2.DateKey,
    d3.DateKey,
    c.CurrencyKey,
    ps.PaymentStatusKey,
    ar.Amount,
    ar.AppliedRate,
    ar.AmountUSD,
    ar.Terms,
    'AccountsReceivable'
FROM silver.AccountsReceivable ar
JOIN dw.DimCustomer cuk      ON ar.Customer = cuk.CustomerName
JOIN dw.DimDate d1           ON ar.InvoiceDate = d1.FullDate
JOIN dw.DimDate d2           ON ar.DueDate = d2.FullDate
LEFT JOIN dw.DimDate d3      ON ar.ReceivedDate = d3.FullDate  -- LEFT JOIN: ReceivedDate can be NULL
JOIN dw.DimCurrency c        ON ar.Currency = c.CurrencyCode
JOIN dw.DimPaymentStatus ps  ON ar.Status_ = ps.StatusName AND ps.ProcessType = 'AccountsReceivable';
GO

-- -------------------------------------------------------------
-- FactExpenseClaims
-- -------------------------------------------------------------
CREATE TABLE dw.FactExpenseClaims (
    FactExpenseClaimsKey INT IDENTITY(1,1) PRIMARY KEY,
    ClaimID              VARCHAR(50) NOT NULL UNIQUE,
    EmployeeKey          INT NOT NULL,
    ExpenseCategoryKey   INT NOT NULL,
    SubmitDateKey        INT NOT NULL,
    PayDateKey           INT NULL,
    CurrencyKey          INT NOT NULL,
    PaymentStatusKey     INT NOT NULL,
    Amount               DECIMAL(18,2) NOT NULL,
    AppliedRate          DECIMAL(10,4) NOT NULL,
    AmountUSD            DECIMAL(18,2) NOT NULL,
    ClaimDescription     VARCHAR(500) NULL,
    ApprovedBy           VARCHAR(150) NULL,
    SourceFile           VARCHAR(255) NULL,
    LoadDate             DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_FactExpense_Employee   FOREIGN KEY (EmployeeKey)        REFERENCES dw.DimEmployee(EmployeeKey),
    CONSTRAINT FK_FactExpense_Category   FOREIGN KEY (ExpenseCategoryKey) REFERENCES dw.DimExpenseCategory(ExpenseCategoryKey),
    CONSTRAINT FK_FactExpense_SubmitDate FOREIGN KEY (SubmitDateKey)      REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactExpense_PayDate    FOREIGN KEY (PayDateKey)         REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactExpense_Currency   FOREIGN KEY (CurrencyKey)        REFERENCES dw.DimCurrency(CurrencyKey),
    CONSTRAINT FK_FactExpense_Status     FOREIGN KEY (PaymentStatusKey)   REFERENCES dw.DimPaymentStatus(PaymentStatusKey)
);
GO

INSERT INTO dw.FactExpenseClaims
(ClaimID, EmployeeKey, ExpenseCategoryKey, SubmitDateKey, PayDateKey, CurrencyKey, PaymentStatusKey, Amount, AppliedRate, AmountUSD, ClaimDescription, ApprovedBy, SourceFile)
SELECT
    ec.ClaimID,
    emp.EmployeeKey,
    cat.ExpenseCategoryKey,
    d1.DateKey,
    d2.DateKey,
    crk.CurrencyKey,
    ps.PaymentStatusKey,
    ec.Amount,
    ec.AppliedRate,
    ec.AmountUSD,
    ec.Description_,
    ec.ApprovedBy,
    'ExpenseClaims'
FROM silver.ExpenseClaims ec
JOIN dw.DimEmployee emp        ON ec.EmployeeID = emp.EmployeeID
JOIN dw.DimExpenseCategory cat ON ec.Category = cat.CategoryName
JOIN dw.DimDate d1             ON ec.SubmitDate = d1.FullDate
LEFT JOIN dw.DimDate d2        ON ec.PayDate = d2.FullDate      -- LEFT JOIN: PayDate can be NULL
JOIN dw.DimCurrency crk        ON ec.Currency = crk.CurrencyCode
JOIN dw.DimPaymentStatus ps    ON ec.Status_ = ps.StatusName AND ps.ProcessType = 'ExpenseClaims';
GO

-- -------------------------------------------------------------
-- FactBudgetForecast (no currency join needed -- already USD;
-- BudgetDateKey uses the first day of the fiscal quarter,
-- since the source grain is quarterly, not daily)
-- -------------------------------------------------------------
CREATE TABLE dw.FactBudgetForecast (
    FactBudgetForecastKey INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentKey          INT NOT NULL,
    BudgetDateKey           INT NOT NULL,
    BudgetUSD               DECIMAL(18,2) NOT NULL,
    ForecastUSD              DECIMAL(18,2) NOT NULL,
    ActualUSD                DECIMAL(18,2) NOT NULL,
    VarianceUSD               DECIMAL(18,2) NOT NULL,
    Notes                     VARCHAR(500) NULL,
    SourceFile                VARCHAR(255) NULL,
    LoadDate                  DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_FactBudget_DepartmentPeriod UNIQUE (DepartmentKey, BudgetDateKey),
    CONSTRAINT FK_FactBudget_Department FOREIGN KEY (DepartmentKey) REFERENCES dw.DimDepartment(DepartmentKey),
    CONSTRAINT FK_FactBudget_Date       FOREIGN KEY (BudgetDateKey) REFERENCES dw.DimDate(DateKey)
);
GO

INSERT INTO dw.FactBudgetForecast
(DepartmentKey, BudgetDateKey, BudgetUSD, ForecastUSD, ActualUSD, VarianceUSD, Notes, SourceFile)
SELECT
    d.DepartmentKey,
    dt.DateKey,
    bf.BudgetUSD,
    bf.ForecastUSD,
    bf.ActualUSD,
    bf.VarianceUSD,
    bf.Notes,
    'BudgetForecast'
FROM silver.BudgetForecast bf
JOIN dw.DimDepartment d ON bf.Dept = d.DepartmentName
JOIN dw.DimDate dt      ON dt.FullDate = DATEFROMPARTS(bf.FiscalYear, ((bf.Quarter_ - 1) * 3) + 1, 1);
GO

-- -------------------------------------------------------------
-- FactGeneralLedger
-- -------------------------------------------------------------
CREATE TABLE dw.FactGeneralLedger (
    FactGeneralLedgerKey   INT IDENTITY(1,1) PRIMARY KEY,
    GLID                   VARCHAR(50) NOT NULL UNIQUE,
    TransactionDateKey     INT NOT NULL,
    AccountKey             INT NOT NULL,
    DepartmentKey          INT NOT NULL,
    CostCenterKey          INT NOT NULL,
    CurrencyKey            INT NOT NULL,
    Debit                  DECIMAL(18,2) NOT NULL,
    Credit                 DECIMAL(18,2) NOT NULL,
    AppliedRate            DECIMAL(10,4) NOT NULL,
    DebitUSD               DECIMAL(18,2) NOT NULL,
    CreditUSD              DECIMAL(18,2) NOT NULL,
    TransactionDescription VARCHAR(500) NULL,
    SourceFile             VARCHAR(255) NULL,
    LoadDate                DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_FactGL_Date       FOREIGN KEY (TransactionDateKey) REFERENCES dw.DimDate(DateKey),
    CONSTRAINT FK_FactGL_Account    FOREIGN KEY (AccountKey)         REFERENCES dw.DimAccount(AccountKey),
    CONSTRAINT FK_FactGL_Department FOREIGN KEY (DepartmentKey)      REFERENCES dw.DimDepartment(DepartmentKey),
    CONSTRAINT FK_FactGL_CostCenter FOREIGN KEY (CostCenterKey)      REFERENCES dw.DimCostCenter(CostCenterKey),
    CONSTRAINT FK_FactGL_Currency   FOREIGN KEY (CurrencyKey)        REFERENCES dw.DimCurrency(CurrencyKey)
);
GO

INSERT INTO dw.FactGeneralLedger
(GLID, TransactionDateKey, AccountKey, DepartmentKey, CostCenterKey, CurrencyKey, Debit, Credit, AppliedRate, DebitUSD, CreditUSD, TransactionDescription, SourceFile)
SELECT
    gl.GLID,
    d.DateKey,
    acc.AccountKey,
    dep.DepartmentKey,
    cc.CostCenterKey,
    cur.CurrencyKey,
    gl.Debit,
    gl.Credit,
    gl.AppliedRate,
    gl.DebitUSD,
    gl.CreditUSD,
    gl.Description,
    'GeneralLedger'
FROM silver.GeneralLedger gl
JOIN dw.DimDate d           ON gl.TxnDate = d.FullDate
JOIN dw.DimAccount acc      ON gl.AccountNumber = acc.AccountNumber
JOIN dw.DimDepartment dep   ON gl.Dept = dep.DepartmentName
JOIN dw.DimCostCenter cc    ON gl.CostCenter = cc.CostCenterCode
JOIN dw.DimCurrency cur     ON gl.Currency = cur.CurrencyCode;
GO
