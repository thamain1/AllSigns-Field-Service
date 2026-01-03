/*
  # ERP/Accounting Schema

  ## Overview
  This migration creates a complete native accounting engine with General Ledger, Chart of Accounts,
  Accounts Receivable, and Accounts Payable. Pre-configured for HVAC business operations.

  ## 1. New Tables

  ### Chart of Accounts (COA)
    - `chart_of_accounts` - Account structure and categories
      - `id` (uuid, primary key)
      - `account_code` (text, unique) - e.g., "1000", "4100"
      - `account_name` (text) - Account name
      - `account_type` (enum) - asset, liability, equity, revenue, expense
      - `account_subtype` (text) - Cash, AR, Fixed Assets, Service Revenue, COGS, etc.
      - `parent_account_id` (uuid, nullable) - For sub-accounts
      - `is_active` (boolean) - Active status
      - `description` (text) - Account description
      - `normal_balance` (enum) - debit, credit
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### General Ledger (GL)
    - `gl_entries` - All financial transactions
      - `id` (uuid, primary key)
      - `entry_number` (text, unique) - Auto-generated entry number
      - `entry_date` (date) - Transaction date
      - `account_id` (uuid) - Foreign key to chart_of_accounts
      - `debit_amount` (decimal) - Debit amount
      - `credit_amount` (decimal) - Credit amount
      - `description` (text) - Transaction description
      - `reference_type` (text) - invoice, payment, payroll, adjustment, etc.
      - `reference_id` (uuid, nullable) - ID of related record
      - `posted_by` (uuid) - Foreign key to profiles
      - `is_posted` (boolean) - Posted to ledger
      - `fiscal_year` (integer) - Year for reporting
      - `fiscal_period` (integer) - Month/period for reporting
      - `created_at` (timestamptz)

  ### Accounts Payable (AP)
    - `vendor_bills` - Bills from vendors/suppliers
      - `id` (uuid, primary key)
      - `bill_number` (text, unique) - Vendor bill number
      - `vendor_name` (text) - Vendor/supplier name
      - `vendor_id` (uuid, nullable) - Future vendor table link
      - `bill_date` (date) - Bill date
      - `due_date` (date) - Payment due date
      - `amount` (decimal) - Bill amount
      - `amount_paid` (decimal) - Amount paid
      - `balance_due` (decimal) - Remaining balance
      - `status` (enum) - unpaid, partial, paid, overdue
      - `category` (text) - Parts, Supplies, Utilities, etc.
      - `description` (text) - Bill description
      - `notes` (text) - Internal notes
      - `gl_posted` (boolean) - Posted to GL
      - `created_by` (uuid) - Foreign key to profiles
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Bank Reconciliation
    - `bank_reconciliations` - Manual bank reconciliation tracking
      - `id` (uuid, primary key)
      - `account_id` (uuid) - Foreign key to chart_of_accounts (bank account)
      - `reconciliation_date` (date) - Date of reconciliation
      - `statement_balance` (decimal) - Ending balance per bank statement
      - `book_balance` (decimal) - Balance per accounting records
      - `difference` (decimal) - Unreconciled difference
      - `status` (enum) - in_progress, reconciled
      - `notes` (text) - Reconciliation notes
      - `reconciled_by` (uuid) - Foreign key to profiles
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ## 2. Pre-configured Chart of Accounts for HVAC
    - Assets: Cash, AR, Inventory, Vehicles, Equipment
    - Liabilities: AP, Credit Cards, Loans
    - Equity: Owner's Equity, Retained Earnings
    - Revenue: Service Revenue, Parts Sales, Maintenance Contracts
    - Expenses: Labor, COGS-Parts, Vehicle, Utilities, Insurance

  ## 3. Security
    - Enable RLS on all tables
    - Admin and dispatcher roles have full access
    - Technicians have read-only access to certain reports

  ## 4. Indexes
    - Account codes for quick lookup
    - Entry dates for period-based reporting
    - Reference IDs for transaction tracking
*/

-- Create account type enum
DO $$ BEGIN
  CREATE TYPE account_type AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create normal balance enum
DO $$ BEGIN
  CREATE TYPE normal_balance AS ENUM ('debit', 'credit');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create AP status enum
DO $$ BEGIN
  CREATE TYPE ap_status AS ENUM ('unpaid', 'partial', 'paid', 'overdue');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create reconciliation status enum
DO $$ BEGIN
  CREATE TYPE reconciliation_status AS ENUM ('in_progress', 'reconciled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create chart of accounts table
CREATE TABLE IF NOT EXISTS chart_of_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_code text UNIQUE NOT NULL,
  account_name text NOT NULL,
  account_type account_type NOT NULL,
  account_subtype text,
  parent_account_id uuid REFERENCES chart_of_accounts(id) ON DELETE SET NULL,
  is_active boolean DEFAULT true,
  description text,
  normal_balance normal_balance NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create general ledger table
CREATE TABLE IF NOT EXISTS gl_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_number text UNIQUE NOT NULL,
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  account_id uuid NOT NULL REFERENCES chart_of_accounts(id) ON DELETE RESTRICT,
  debit_amount decimal(10,2) DEFAULT 0,
  credit_amount decimal(10,2) DEFAULT 0,
  description text NOT NULL,
  reference_type text,
  reference_id uuid,
  posted_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  is_posted boolean DEFAULT true,
  fiscal_year integer NOT NULL,
  fiscal_period integer NOT NULL CHECK (fiscal_period >= 1 AND fiscal_period <= 12),
  created_at timestamptz DEFAULT now()
);

-- Create vendor bills (AP) table
CREATE TABLE IF NOT EXISTS vendor_bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_number text UNIQUE NOT NULL,
  vendor_name text NOT NULL,
  vendor_id uuid,
  bill_date date NOT NULL DEFAULT CURRENT_DATE,
  due_date date NOT NULL,
  amount decimal(10,2) NOT NULL CHECK (amount > 0),
  amount_paid decimal(10,2) DEFAULT 0,
  balance_due decimal(10,2) NOT NULL,
  status ap_status DEFAULT 'unpaid',
  category text,
  description text,
  notes text,
  gl_posted boolean DEFAULT false,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create bank reconciliations table
CREATE TABLE IF NOT EXISTS bank_reconciliations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES chart_of_accounts(id) ON DELETE RESTRICT,
  reconciliation_date date NOT NULL,
  statement_balance decimal(10,2) NOT NULL,
  book_balance decimal(10,2) NOT NULL,
  difference decimal(10,2) NOT NULL,
  status reconciliation_status DEFAULT 'in_progress',
  notes text,
  reconciled_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Insert default HVAC Chart of Accounts
INSERT INTO chart_of_accounts (account_code, account_name, account_type, account_subtype, normal_balance, description) VALUES
-- Assets (1000-1999)
('1000', 'Cash - Operating', 'asset', 'Cash', 'debit', 'Main operating bank account'),
('1100', 'Accounts Receivable', 'asset', 'Accounts Receivable', 'debit', 'Customer invoices outstanding'),
('1200', 'Parts Inventory', 'asset', 'Inventory', 'debit', 'HVAC parts and supplies on hand'),
('1500', 'Vehicles', 'asset', 'Fixed Assets', 'debit', 'Service vehicles and trucks'),
('1600', 'Tools & Equipment', 'asset', 'Fixed Assets', 'debit', 'HVAC tools and equipment'),
('1700', 'Accumulated Depreciation', 'asset', 'Contra Asset', 'credit', 'Accumulated depreciation on fixed assets'),

-- Liabilities (2000-2999)
('2000', 'Accounts Payable', 'liability', 'Accounts Payable', 'credit', 'Bills owed to vendors and suppliers'),
('2100', 'Credit Card', 'liability', 'Credit Card', 'credit', 'Business credit card balances'),
('2200', 'Payroll Liabilities', 'liability', 'Payroll', 'credit', 'Wages and taxes payable'),
('2300', 'Vehicle Loans', 'liability', 'Long-term Debt', 'credit', 'Loans on service vehicles'),

-- Equity (3000-3999)
('3000', 'Owner Equity', 'equity', 'Owner Equity', 'credit', 'Owner capital investment'),
('3900', 'Retained Earnings', 'equity', 'Retained Earnings', 'credit', 'Accumulated business profits'),

-- Revenue (4000-4999)
('4000', 'Service Revenue', 'revenue', 'Service Income', 'credit', 'HVAC service and repair revenue'),
('4100', 'Installation Revenue', 'revenue', 'Installation Income', 'credit', 'New system installation revenue'),
('4200', 'Maintenance Contract Revenue', 'revenue', 'Contract Income', 'credit', 'Recurring maintenance contract income'),
('4300', 'Parts Sales', 'revenue', 'Parts Income', 'credit', 'Revenue from parts sold separately'),

-- Expenses (5000-9999)
('5000', 'Cost of Goods Sold - Parts', 'expense', 'COGS', 'debit', 'Cost of parts used in jobs'),
('6000', 'Labor - Technicians', 'expense', 'Labor', 'debit', 'Technician wages and salaries'),
('6100', 'Payroll Taxes', 'expense', 'Payroll Expense', 'debit', 'Employer payroll taxes'),
('6200', 'Vehicle Fuel', 'expense', 'Vehicle Expense', 'debit', 'Fuel for service vehicles'),
('6300', 'Vehicle Maintenance', 'expense', 'Vehicle Expense', 'debit', 'Vehicle repairs and maintenance'),
('6400', 'Insurance - Liability', 'expense', 'Insurance', 'debit', 'Business liability insurance'),
('6500', 'Insurance - Vehicle', 'expense', 'Insurance', 'debit', 'Vehicle insurance'),
('6600', 'Rent - Office/Warehouse', 'expense', 'Occupancy', 'debit', 'Rent for business premises'),
('6700', 'Utilities', 'expense', 'Utilities', 'debit', 'Electric, gas, water, phone'),
('6800', 'Marketing & Advertising', 'expense', 'Marketing', 'debit', 'Advertising and promotional costs'),
('6900', 'Office Supplies', 'expense', 'Office', 'debit', 'General office supplies and equipment'),
('7000', 'Professional Fees', 'expense', 'Professional Services', 'debit', 'Accounting, legal fees'),
('7100', 'Licensing & Permits', 'expense', 'Regulatory', 'debit', 'Business licenses and permits')
ON CONFLICT (account_code) DO NOTHING;

-- Enable RLS
ALTER TABLE chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE gl_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_reconciliations ENABLE ROW LEVEL SECURITY;

-- COA policies - read-only for all, admin can modify
CREATE POLICY "All authenticated users can view COA"
  ON chart_of_accounts FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage COA"
  ON chart_of_accounts FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- GL policies - admins and dispatchers
CREATE POLICY "Managers can view GL entries"
  ON gl_entries FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Managers can create GL entries"
  ON gl_entries FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Admins can update GL entries"
  ON gl_entries FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

CREATE POLICY "Admins can delete GL entries"
  ON gl_entries FOR DELETE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Vendor bills policies
CREATE POLICY "Managers can view vendor bills"
  ON vendor_bills FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Managers can create vendor bills"
  ON vendor_bills FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Managers can update vendor bills"
  ON vendor_bills FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Admins can delete vendor bills"
  ON vendor_bills FOR DELETE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Bank reconciliation policies
CREATE POLICY "Managers can view bank reconciliations"
  ON bank_reconciliations FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Managers can create bank reconciliations"
  ON bank_reconciliations FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Managers can update bank reconciliations"
  ON bank_reconciliations FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Admins can delete bank reconciliations"
  ON bank_reconciliations FOR DELETE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_coa_account_code ON chart_of_accounts(account_code);
CREATE INDEX IF NOT EXISTS idx_coa_account_type ON chart_of_accounts(account_type);
CREATE INDEX IF NOT EXISTS idx_gl_entry_number ON gl_entries(entry_number);
CREATE INDEX IF NOT EXISTS idx_gl_entry_date ON gl_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_gl_account ON gl_entries(account_id);
CREATE INDEX IF NOT EXISTS idx_gl_reference ON gl_entries(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_gl_fiscal ON gl_entries(fiscal_year, fiscal_period);
CREATE INDEX IF NOT EXISTS idx_vendor_bills_number ON vendor_bills(bill_number);
CREATE INDEX IF NOT EXISTS idx_vendor_bills_due_date ON vendor_bills(due_date);
CREATE INDEX IF NOT EXISTS idx_vendor_bills_status ON vendor_bills(status);
CREATE INDEX IF NOT EXISTS idx_bank_rec_account ON bank_reconciliations(account_id);
CREATE INDEX IF NOT EXISTS idx_bank_rec_date ON bank_reconciliations(reconciliation_date);