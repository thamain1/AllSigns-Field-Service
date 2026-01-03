/*
  # Create Project Billing Schedules Table

  1. New Enums
    - billing_type - How milestone amount is calculated
    - billing_schedule_status - Lifecycle status of milestone

  2. New Table: project_billing_schedules
    - Tracks milestones and progress billing for projects
    - Supports deposits, retainage, and progress payments
    - Links to invoices when billed

  3. Security
    - RLS enabled
    - Authenticated users can view
    - Admin/dispatcher can manage

  4. Important Notes
    - Pure additive schema
    - No changes to existing tables yet
*/

-- =====================================================
-- ENUMS
-- =====================================================

CREATE TYPE billing_type AS ENUM (
  'fixed_amount',
  'percent_of_contract'
);

CREATE TYPE billing_schedule_status AS ENUM (
  'planned',
  'ready_to_bill',
  'billed',
  'partially_billed',
  'cancelled'
);

-- =====================================================
-- PROJECT BILLING SCHEDULES TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS project_billing_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  
  -- Milestone details
  sequence integer NOT NULL DEFAULT 1,
  name text NOT NULL,
  description text,
  
  -- Billing amount calculation
  billing_type billing_type NOT NULL DEFAULT 'percent_of_contract',
  amount numeric(15, 2),
  percent_of_contract numeric(5, 2),
  
  -- Special milestone types
  is_deposit boolean DEFAULT false,
  is_retainage boolean DEFAULT false,
  
  -- Status tracking
  status billing_schedule_status DEFAULT 'planned',
  target_event text,
  target_date date,
  
  -- Invoice linkage
  invoice_id uuid REFERENCES invoices(id) ON DELETE SET NULL,
  billed_amount numeric(15, 2) DEFAULT 0,
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES profiles(id),
  updated_by uuid REFERENCES profiles(id),
  
  -- Constraints
  CONSTRAINT valid_billing_amount CHECK (
    (billing_type = 'fixed_amount' AND amount IS NOT NULL) OR
    (billing_type = 'percent_of_contract' AND percent_of_contract IS NOT NULL)
  ),
  CONSTRAINT valid_percent CHECK (
    percent_of_contract IS NULL OR 
    (percent_of_contract >= 0 AND percent_of_contract <= 100)
  ),
  CONSTRAINT positive_amounts CHECK (
    (amount IS NULL OR amount >= 0) AND
    (billed_amount >= 0)
  )
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_billing_schedules_project_id 
  ON project_billing_schedules(project_id);

CREATE INDEX IF NOT EXISTS idx_billing_schedules_status 
  ON project_billing_schedules(status);

CREATE INDEX IF NOT EXISTS idx_billing_schedules_invoice_id 
  ON project_billing_schedules(invoice_id) WHERE invoice_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_billing_schedules_sequence 
  ON project_billing_schedules(project_id, sequence);

-- =====================================================
-- RLS POLICIES
-- =====================================================

ALTER TABLE project_billing_schedules ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view billing schedules
CREATE POLICY "Authenticated users can view billing schedules"
  ON project_billing_schedules FOR SELECT TO authenticated
  USING (true);

-- Admin and dispatchers can manage billing schedules
CREATE POLICY "Admin and dispatchers can manage billing schedules"
  ON project_billing_schedules FOR ALL TO authenticated
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
-- TRIGGERS
-- =====================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_billing_schedules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER billing_schedules_updated_at
  BEFORE UPDATE ON project_billing_schedules
  FOR EACH ROW
  EXECUTE FUNCTION update_billing_schedules_updated_at();

-- =====================================================
-- HELPER FUNCTION: Calculate Milestone Amount
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_milestone_amount(
  p_billing_schedule_id uuid
)
RETURNS numeric AS $$
DECLARE
  v_schedule RECORD;
  v_contract_value numeric;
BEGIN
  -- Get billing schedule details
  SELECT 
    bs.*,
    COALESCE(p.contract_value_site, p.contract_value_total, p.budget) as contract_val
  INTO v_schedule
  FROM project_billing_schedules bs
  JOIN projects p ON p.id = bs.project_id
  WHERE bs.id = p_billing_schedule_id;
  
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  
  v_contract_value := v_schedule.contract_val;
  
  -- Calculate based on billing type
  IF v_schedule.billing_type = 'fixed_amount' THEN
    RETURN v_schedule.amount;
  ELSIF v_schedule.billing_type = 'percent_of_contract' AND v_contract_value IS NOT NULL THEN
    RETURN v_contract_value * (v_schedule.percent_of_contract / 100);
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;
