/*
  # Enhance Bank Reconciliation System
  
  1. Updates to Existing bank_reconciliations Table
    - Add missing columns for comprehensive reconciliation tracking
    
  2. New Tables  
    - `bank_statement_lines` - Imported bank statement transactions
    - `reconciliation_adjustments` - Adjustment journal entries
    
  3. GL Entries Enhancement (Additive Only)
    - Add reconciliation tracking columns
    
  4. Functions and Views
    - Helper functions for reconciliation workflow
*/

-- Create enums if they don't exist
DO $$ BEGIN
  CREATE TYPE reconciliation_status AS ENUM (
    'in_progress',
    'completed',
    'cancelled',
    'rolled_back'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE bank_line_match_status AS ENUM (
    'unmatched',
    'auto_matched',
    'manually_matched',
    'excluded'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE reconciliation_adjustment_type AS ENUM (
    'bank_fee',
    'interest_income',
    'nsf',
    'correction',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Add columns to existing bank_reconciliations table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'statement_start_date'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN statement_start_date date;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'statement_end_date'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN statement_end_date date;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'statement_ending_balance'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN statement_ending_balance decimal(15,2);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'calculated_book_balance'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN calculated_book_balance decimal(15,2);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'cleared_balance'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN cleared_balance decimal(15,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'created_by'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN created_by uuid REFERENCES profiles(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'completed_at'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN completed_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'completed_by'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN completed_by uuid REFERENCES profiles(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'cancelled_at'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN cancelled_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'cancelled_by'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN cancelled_by uuid REFERENCES profiles(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'rolled_back_at'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN rolled_back_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_reconciliations' AND column_name = 'rolled_back_by'
  ) THEN
    ALTER TABLE bank_reconciliations ADD COLUMN rolled_back_by uuid REFERENCES profiles(id);
  END IF;
END $$;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_bank_reconciliations_statement_dates 
  ON bank_reconciliations(statement_start_date, statement_end_date);
CREATE INDEX IF NOT EXISTS idx_bank_reconciliations_status_v2
  ON bank_reconciliations(status) WHERE status IS NOT NULL;

-- Add reconciliation columns to gl_entries (non-destructive)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'gl_entries' AND column_name = 'reconciliation_id'
  ) THEN
    ALTER TABLE gl_entries ADD COLUMN reconciliation_id uuid REFERENCES bank_reconciliations(id) ON DELETE SET NULL;
    CREATE INDEX idx_gl_entries_reconciliation_id ON gl_entries(reconciliation_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'gl_entries' AND column_name = 'cleared_at'
  ) THEN
    ALTER TABLE gl_entries ADD COLUMN cleared_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'gl_entries' AND column_name = 'cleared_by_user_id'
  ) THEN
    ALTER TABLE gl_entries ADD COLUMN cleared_by_user_id uuid REFERENCES profiles(id);
  END IF;
END $$;

-- Create bank_statement_lines table
CREATE TABLE IF NOT EXISTS bank_statement_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reconciliation_id uuid NOT NULL REFERENCES bank_reconciliations(id) ON DELETE CASCADE,
  external_transaction_id text,
  transaction_date date NOT NULL,
  description text NOT NULL,
  amount decimal(15,2) NOT NULL,
  balance decimal(15,2),
  matched_gl_entry_id uuid REFERENCES gl_entries(id) ON DELETE SET NULL,
  match_status bank_line_match_status DEFAULT 'unmatched',
  matched_at timestamptz,
  matched_by uuid REFERENCES profiles(id),
  notes text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_reconciliation ON bank_statement_lines(reconciliation_id);
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_date ON bank_statement_lines(transaction_date);
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_matched_gl ON bank_statement_lines(matched_gl_entry_id);
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_match_status ON bank_statement_lines(match_status);

-- Create reconciliation_adjustments table
CREATE TABLE IF NOT EXISTS reconciliation_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reconciliation_id uuid NOT NULL REFERENCES bank_reconciliations(id) ON DELETE CASCADE,
  gl_entry_id uuid REFERENCES gl_entries(id) ON DELETE CASCADE,
  adjustment_type reconciliation_adjustment_type NOT NULL,
  description text NOT NULL,
  amount decimal(15,2) NOT NULL,
  debit_account_id uuid REFERENCES chart_of_accounts(id),
  credit_account_id uuid REFERENCES chart_of_accounts(id),
  created_by uuid NOT NULL REFERENCES profiles(id),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reconciliation_adjustments_reconciliation ON reconciliation_adjustments(reconciliation_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_adjustments_gl_entry ON reconciliation_adjustments(gl_entry_id);

-- Enable RLS on new tables
ALTER TABLE bank_statement_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE reconciliation_adjustments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for bank_statement_lines
CREATE POLICY "Admins can view bank statement lines"
  ON bank_statement_lines FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can manage bank statement lines"
  ON bank_statement_lines FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- RLS Policies for reconciliation_adjustments
CREATE POLICY "Admins can view adjustments"
  ON reconciliation_adjustments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can create adjustments"
  ON reconciliation_adjustments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Helper functions

-- Function to get unreconciled GL entries for an account
CREATE OR REPLACE FUNCTION get_unreconciled_gl_entries(
  p_account_id uuid,
  p_end_date date DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  entry_number text,
  entry_date date,
  description text,
  reference_type text,
  reference_id uuid,
  debit_amount decimal,
  credit_amount decimal,
  net_amount decimal,
  created_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ge.id,
    ge.entry_number,
    ge.entry_date,
    ge.description,
    ge.reference_type,
    ge.reference_id,
    ge.debit_amount,
    ge.credit_amount,
    CASE 
      WHEN ge.debit_amount > 0 THEN ge.debit_amount
      ELSE -ge.credit_amount
    END as net_amount,
    ge.created_at
  FROM gl_entries ge
  WHERE ge.account_id = p_account_id
    AND ge.reconciliation_id IS NULL
    AND (p_end_date IS NULL OR ge.entry_date <= p_end_date)
  ORDER BY ge.entry_date, ge.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate cleared balance for a reconciliation
CREATE OR REPLACE FUNCTION calculate_cleared_balance(p_reconciliation_id uuid)
RETURNS decimal AS $$
DECLARE
  v_cleared_balance decimal;
BEGIN
  SELECT COALESCE(SUM(
    CASE 
      WHEN debit_amount > 0 THEN debit_amount
      ELSE -credit_amount
    END
  ), 0)
  INTO v_cleared_balance
  FROM gl_entries
  WHERE reconciliation_id = p_reconciliation_id;
  
  RETURN v_cleared_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update reconciliation balances
CREATE OR REPLACE FUNCTION update_reconciliation_balances(p_reconciliation_id uuid)
RETURNS void AS $$
DECLARE
  v_cleared_balance decimal;
  v_statement_balance decimal;
  v_difference decimal;
BEGIN
  -- Get cleared balance
  v_cleared_balance := calculate_cleared_balance(p_reconciliation_id);
  
  -- Get statement balance (try new column first, fallback to old)
  SELECT COALESCE(statement_ending_balance, statement_balance)
  INTO v_statement_balance
  FROM bank_reconciliations
  WHERE id = p_reconciliation_id;
  
  -- Calculate difference
  v_difference := v_statement_balance - v_cleared_balance;
  
  -- Update reconciliation
  UPDATE bank_reconciliations
  SET 
    cleared_balance = v_cleared_balance,
    difference = v_difference
  WHERE id = p_reconciliation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-update reconciliation balances when GL entries are cleared
CREATE OR REPLACE FUNCTION trigger_update_reconciliation_balances()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.reconciliation_id IS NOT NULL THEN
    PERFORM update_reconciliation_balances(NEW.reconciliation_id);
  END IF;
  
  IF TG_OP = 'UPDATE' AND OLD.reconciliation_id IS NOT NULL AND 
     OLD.reconciliation_id != COALESCE(NEW.reconciliation_id, '00000000-0000-0000-0000-000000000000'::uuid) THEN
    PERFORM update_reconciliation_balances(OLD.reconciliation_id);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_gl_entry_reconciliation_update ON gl_entries;
CREATE TRIGGER trigger_gl_entry_reconciliation_update
  AFTER INSERT OR UPDATE OF reconciliation_id ON gl_entries
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_reconciliation_balances();

-- Function to auto-match bank statement lines to GL entries
CREATE OR REPLACE FUNCTION auto_match_bank_lines(p_reconciliation_id uuid)
RETURNS TABLE (
  bank_line_id uuid,
  gl_entry_id uuid,
  match_confidence decimal
) AS $$
BEGIN
  RETURN QUERY
  WITH recon_info AS (
    SELECT account_id, statement_end_date
    FROM bank_reconciliations
    WHERE id = p_reconciliation_id
  ),
  unmatched_bank_lines AS (
    SELECT 
      bsl.id as bank_line_id,
      bsl.transaction_date,
      bsl.amount,
      bsl.description
    FROM bank_statement_lines bsl
    WHERE bsl.reconciliation_id = p_reconciliation_id
      AND bsl.match_status = 'unmatched'
  ),
  unmatched_gl_entries AS (
    SELECT 
      ge.id as gl_entry_id,
      ge.entry_date,
      CASE 
        WHEN ge.debit_amount > 0 THEN ge.debit_amount
        ELSE -ge.credit_amount
      END as net_amount,
      ge.description
    FROM gl_entries ge
    CROSS JOIN recon_info ri
    WHERE ge.account_id = ri.account_id
      AND ge.reconciliation_id IS NULL
      AND ge.entry_date <= ri.statement_end_date
  )
  SELECT 
    bl.bank_line_id,
    ge.gl_entry_id,
    CASE
      WHEN bl.transaction_date = ge.entry_date AND bl.amount = ge.net_amount THEN 1.0
      WHEN ABS(bl.transaction_date - ge.entry_date) <= 3 AND bl.amount = ge.net_amount THEN 0.9
      WHEN ABS(bl.transaction_date - ge.entry_date) <= 5 AND bl.amount = ge.net_amount THEN 0.7
      ELSE 0.0
    END::decimal as match_confidence
  FROM unmatched_bank_lines bl
  CROSS JOIN unmatched_gl_entries ge
  WHERE bl.amount = ge.net_amount
    AND ABS(bl.transaction_date - ge.entry_date) <= 5
  ORDER BY match_confidence DESC, bl.bank_line_id, ge.gl_entry_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
