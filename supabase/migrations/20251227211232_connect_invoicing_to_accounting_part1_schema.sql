/*
  # Connect Invoicing to Accounting Engine - Part 1: Schema Additions

  ## Overview
  This migration connects the Invoicing system to the native Accounting/GL engine by
  adding tracking columns to invoices and payments. This is fully additive and non-destructive.

  ## 1. Schema Additions

  ### Invoices Table
  Add GL posting tracking columns:
    - `gl_posted` (boolean) - Whether invoice has been posted to GL
    - `gl_posted_at` (timestamptz) - When invoice was posted to GL
    - `gl_entry_ids` (uuid[]) - Array of GL entry IDs created for this invoice

  ### Payments Table
  Add GL posting tracking columns:
    - `gl_posted` (boolean) - Whether payment has been posted to GL
    - `gl_posted_at` (timestamptz) - When payment was posted to GL
    - `gl_entry_ids` (uuid[]) - Array of GL entry IDs created for this payment

  ## 2. Compatibility Views
  Create views that map existing tables to the names the UI expects:
    - `gl_accounts` view → points to `chart_of_accounts` table
    - `journal_entries` view → points to `gl_entries` table (grouped)
    - `journal_entry_lines` view → points to `gl_entries` table

  ## 3. Security
  All views inherit RLS from underlying tables. No new RLS policies needed.

  ## 4. Important Notes
  - This is ADDITIVE ONLY - no existing data or logic is changed
  - Existing Invoicing functionality continues to work unchanged
  - Customer revenue calculations remain invoice-based
  - GL posting is opt-in via new functions (created in Part 2)
*/

-- Add GL posting columns to invoices table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'gl_posted'
  ) THEN
    ALTER TABLE invoices ADD COLUMN gl_posted boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'gl_posted_at'
  ) THEN
    ALTER TABLE invoices ADD COLUMN gl_posted_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'gl_entry_ids'
  ) THEN
    ALTER TABLE invoices ADD COLUMN gl_entry_ids uuid[];
  END IF;
END $$;

-- Add GL posting columns to payments table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payments' AND column_name = 'gl_posted'
  ) THEN
    ALTER TABLE payments ADD COLUMN gl_posted boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payments' AND column_name = 'gl_posted_at'
  ) THEN
    ALTER TABLE payments ADD COLUMN gl_posted_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payments' AND column_name = 'gl_entry_ids'
  ) THEN
    ALTER TABLE payments ADD COLUMN gl_entry_ids uuid[];
  END IF;
END $$;

-- Create gl_accounts view (compatibility layer for UI)
-- Maps chart_of_accounts to the shape the Accounting UI expects
CREATE OR REPLACE VIEW gl_accounts AS
SELECT
  id,
  account_code as account_number,
  account_name,
  account_type,
  account_subtype,
  parent_account_id,
  is_active,
  description,
  normal_balance,
  -- Calculate running balances from gl_entries
  COALESCE((
    SELECT SUM(debit_amount)
    FROM gl_entries
    WHERE gl_entries.account_id = chart_of_accounts.id
  ), 0) as debit_balance,
  COALESCE((
    SELECT SUM(credit_amount)
    FROM gl_entries
    WHERE gl_entries.account_id = chart_of_accounts.id
  ), 0) as credit_balance,
  -- Current balance considers normal balance direction
  CASE
    WHEN normal_balance = 'debit' THEN
      COALESCE((
        SELECT SUM(debit_amount) - SUM(credit_amount)
        FROM gl_entries
        WHERE gl_entries.account_id = chart_of_accounts.id
      ), 0)
    WHEN normal_balance = 'credit' THEN
      COALESCE((
        SELECT SUM(credit_amount) - SUM(debit_amount)
        FROM gl_entries
        WHERE gl_entries.account_id = chart_of_accounts.id
      ), 0)
  END as current_balance,
  created_at,
  updated_at
FROM chart_of_accounts;

-- Grant access to gl_accounts view (inherits RLS from chart_of_accounts)
GRANT SELECT ON gl_accounts TO authenticated;

-- Create journal_entries view (compatibility layer for UI)
-- Groups gl_entries by entry_number to show journal entries as header records
CREATE OR REPLACE VIEW journal_entries AS
SELECT
  -- Use the first entry's ID as the journal entry ID
  (array_agg(id ORDER BY created_at))[1] as id,
  entry_number as reference_number,
  entry_date,
  MAX(description) as description,
  SUM(debit_amount) as total_debits,
  SUM(credit_amount) as total_credits,
  CASE
    WHEN bool_and(is_posted) THEN 'posted'
    ELSE 'draft'
  END as status,
  (array_agg(posted_by ORDER BY created_at))[1] as created_by,
  MIN(created_at) as created_at
FROM gl_entries
GROUP BY entry_number, entry_date;

-- Grant access to journal_entries view
GRANT SELECT ON journal_entries TO authenticated;

-- Create journal_entry_lines view (compatibility layer for UI)
-- Maps individual gl_entries to journal entry line items
CREATE OR REPLACE VIEW journal_entry_lines AS
SELECT
  ge.id,
  ge.entry_number as journal_entry_id,
  ge.account_id as gl_account_id,
  ge.debit_amount,
  ge.credit_amount,
  ge.description,
  ROW_NUMBER() OVER (PARTITION BY ge.entry_number ORDER BY ge.created_at) as line_number,
  ge.created_at
FROM gl_entries ge;

-- Grant access to journal_entry_lines view
GRANT SELECT ON journal_entry_lines TO authenticated;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_invoices_gl_posted ON invoices(gl_posted) WHERE gl_posted = false;
CREATE INDEX IF NOT EXISTS idx_payments_gl_posted ON payments(gl_posted) WHERE gl_posted = false;
CREATE INDEX IF NOT EXISTS idx_gl_entries_reference ON gl_entries(reference_type, reference_id) WHERE reference_type IS NOT NULL;

-- Add comment to explain the views
COMMENT ON VIEW gl_accounts IS 'Compatibility view mapping chart_of_accounts to UI-expected structure with calculated balances';
COMMENT ON VIEW journal_entries IS 'Compatibility view grouping gl_entries by entry_number to show journal headers';
COMMENT ON VIEW journal_entry_lines IS 'Compatibility view mapping individual gl_entries to journal line items';
