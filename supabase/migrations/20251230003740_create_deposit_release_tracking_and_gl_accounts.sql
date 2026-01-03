/*
  # Create Deposit Release Tracking and GL Account Setup

  1. New Table: project_deposit_releases
    - Tracks when deposits are released from liability to revenue
    - Links original deposit invoice to release journal entry

  2. GL Account Setup
    - Add standard accounts for contract deposits (liability)
    - Add accounts for retainage tracking

  3. Important Notes
    - All additive changes
    - No modifications to existing GL structure
*/

-- =====================================================
-- DEPOSIT RELEASE TRACKING TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS project_deposit_releases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  
  -- Original deposit invoice
  deposit_invoice_id uuid NOT NULL REFERENCES invoices(id),
  deposit_invoice_line_id uuid REFERENCES invoice_line_items(id),
  deposit_amount numeric(15, 2) NOT NULL,
  
  -- Release details
  release_amount numeric(15, 2) NOT NULL,
  release_date date NOT NULL DEFAULT CURRENT_DATE,
  release_reason text,
  
  -- GL entry tracking
  gl_entry_id uuid,
  gl_posted boolean DEFAULT false,
  gl_posted_at timestamptz,
  
  -- Related milestone/invoice (optional)
  related_milestone_id uuid REFERENCES project_billing_schedules(id),
  related_invoice_id uuid REFERENCES invoices(id),
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES profiles(id),
  notes text,
  
  -- Constraints
  CONSTRAINT positive_amounts CHECK (
    deposit_amount > 0 AND
    release_amount > 0 AND
    release_amount <= deposit_amount
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_deposit_releases_project_id 
  ON project_deposit_releases(project_id);

CREATE INDEX IF NOT EXISTS idx_deposit_releases_deposit_invoice 
  ON project_deposit_releases(deposit_invoice_id);

CREATE INDEX IF NOT EXISTS idx_deposit_releases_gl_posted 
  ON project_deposit_releases(gl_posted, gl_posted_at);

-- RLS
ALTER TABLE project_deposit_releases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view deposit releases"
  ON project_deposit_releases FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admin and dispatchers can manage deposit releases"
  ON project_deposit_releases FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'dispatcher')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'dispatcher')
    )
  );

-- =====================================================
-- GL ACCOUNT SETUP FOR DEPOSITS
-- =====================================================

-- Create standard GL accounts for contract deposits if they don't exist
-- These are additive and won't affect existing accounts

DO $$
DECLARE
  v_liability_exists boolean;
  v_revenue_exists boolean;
BEGIN
  -- Check if contract liability account exists
  SELECT EXISTS (
    SELECT 1 FROM chart_of_accounts
    WHERE account_code LIKE '2300%' 
      AND account_name ILIKE '%contract%liabilit%'
  ) INTO v_liability_exists;
  
  -- Create contract liability account if it doesn't exist
  IF NOT v_liability_exists THEN
    INSERT INTO chart_of_accounts (
      account_code,
      account_name,
      account_type,
      account_subtype,
      normal_balance,
      is_active,
      description
    ) VALUES (
      '2350',
      'Contract Liability - Deposits',
      'liability',
      'current_liability',
      'credit',
      true,
      'Unearned revenue from customer deposits and advance payments on projects'
    )
    ON CONFLICT (account_code) DO NOTHING;
  END IF;
  
  -- Check if project revenue account exists
  SELECT EXISTS (
    SELECT 1 FROM chart_of_accounts
    WHERE account_code LIKE '4%' 
      AND account_name ILIKE '%project%revenue%'
  ) INTO v_revenue_exists;
  
  -- Create project revenue account if it doesn't exist
  IF NOT v_revenue_exists THEN
    INSERT INTO chart_of_accounts (
      account_code,
      account_name,
      account_type,
      account_subtype,
      normal_balance,
      is_active,
      description
    ) VALUES (
      '4100',
      'Project Revenue',
      'revenue',
      'operating_revenue',
      'credit',
      true,
      'Revenue from project work and milestone billing'
    )
    ON CONFLICT (account_code) DO NOTHING;
  END IF;

  -- Create retainage receivable account
  INSERT INTO chart_of_accounts (
    account_code,
    account_name,
    account_type,
    account_subtype,
    normal_balance,
    is_active,
    description
  ) VALUES (
    '1250',
    'Retainage Receivable',
    'asset',
    'current_asset',
    'debit',
    true,
    'Amounts withheld by customers as retainage on projects'
  )
  ON CONFLICT (account_code) DO NOTHING;

END $$;

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to get unreleased deposit amount for a project
CREATE OR REPLACE FUNCTION get_unreleased_deposit_amount(p_project_id uuid)
RETURNS numeric AS $$
DECLARE
  v_total_deposits numeric;
  v_total_released numeric;
BEGIN
  -- Get total deposit amounts from invoices
  SELECT COALESCE(SUM(ili.line_total), 0)
  INTO v_total_deposits
  FROM invoice_line_items ili
  JOIN invoices i ON i.id = ili.invoice_id
  WHERE ili.project_id = p_project_id
    AND ili.is_deposit = true
    AND i.status != 'cancelled';
  
  -- Get total released amounts
  SELECT COALESCE(SUM(pdr.release_amount), 0)
  INTO v_total_released
  FROM project_deposit_releases pdr
  WHERE pdr.project_id = p_project_id
    AND pdr.gl_posted = true;
  
  RETURN v_total_deposits - v_total_released;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get billed vs contract value for a project
CREATE OR REPLACE FUNCTION get_project_billing_summary(p_project_id uuid)
RETURNS TABLE (
  contract_value numeric,
  billed_to_date numeric,
  deposits_billed numeric,
  deposits_unreleased numeric,
  revenue_recognized numeric,
  unbilled_amount numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(p.contract_value_site, p.contract_value_total, p.budget) as contract_value,
    COALESCE(SUM(CASE WHEN i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) as billed_to_date,
    COALESCE(SUM(CASE WHEN ili.is_deposit = true AND i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) as deposits_billed,
    get_unreleased_deposit_amount(p_project_id) as deposits_unreleased,
    COALESCE(SUM(CASE WHEN ili.is_deposit = false AND i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) as revenue_recognized,
    COALESCE(p.contract_value_site, p.contract_value_total, p.budget, 0) - 
    COALESCE(SUM(CASE WHEN i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) as unbilled_amount
  FROM projects p
  LEFT JOIN invoice_line_items ili ON ili.project_id = p.id
  LEFT JOIN invoices i ON i.id = ili.invoice_id
  WHERE p.id = p_project_id
  GROUP BY p.id, p.contract_value_site, p.contract_value_total, p.budget;
END;
$$ LANGUAGE plpgsql STABLE;
