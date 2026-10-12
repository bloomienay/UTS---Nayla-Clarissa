
CREATE TABLE IF NOT EXISTS chart_of_accounts (
    account_code VARCHAR(20) PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    normal_balance VARCHAR(6) NOT NULL
        CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    report_classification VARCHAR(30) NOT NULL
);

CREATE TABLE IF NOT EXISTS journal_headers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_date DATE NOT NULL,
    reference_number VARCHAR(50) NOT NULL,
    description TEXT,
    posting_status VARCHAR(10) NOT NULL DEFAULT 'DRAFT'
        CHECK (posting_status IN ('DRAFT', 'POSTED'))
);

CREATE TABLE IF NOT EXISTS journal_lines (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    header_id BIGINT NOT NULL
        REFERENCES journal_headers(id) ON DELETE RESTRICT,
    account_id VARCHAR(20) NOT NULL
        REFERENCES chart_of_accounts(account_code) ON DELETE RESTRICT,
    debit NUMERIC(15,2) NOT NULL DEFAULT 0
        CHECK (debit >= 0),
    credit NUMERIC(15,2) NOT NULL DEFAULT 0
        CHECK (credit >= 0),
    CHECK (debit > 0 OR credit > 0),
    CHECK (debit = 0 OR credit = 0)
);
