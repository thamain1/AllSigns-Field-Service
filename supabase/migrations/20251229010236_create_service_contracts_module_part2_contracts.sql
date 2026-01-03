/*
  # Create Service Contracts Module - Part 2: Customer Contracts

  1. New Tables
    - `service_contracts` - Actual signed customer agreements
      - Links to customer and optional location
      - Links to contract plan template
      - Status tracking (draft, active, expired, cancelled, suspended)
      - Term dates and auto-renewal
      - Snapshotted pricing/coverage from plan
      - Usage tracking (visits used)
      - Billing tracking (next/last billing dates)

  2. New Enums
    - `service_contract_status` - Contract lifecycle status

  3. Security
    - Enable RLS on service_contracts
    - Policies for authenticated users to read contracts
    - Policies for admins/dispatchers to manage contracts

  4. Important Notes
    - Contract pricing/coverage is snapshotted from plan at creation
    - This allows plan templates to change without affecting existing contracts
    - All existing tables remain unchanged
*/

-- Create enum for contract status
DO $$ BEGIN
  CREATE TYPE service_contract_status AS ENUM (
    'draft',
    'active',
    'expired',
    'cancelled',
    'suspended'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Service Contracts table (actual customer agreements)
CREATE TABLE IF NOT EXISTS service_contracts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Links to customer and location
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  customer_location_id UUID REFERENCES customer_locations(id) ON DELETE SET NULL,
  
  -- Link to plan template
  contract_plan_id UUID NOT NULL REFERENCES contract_plans(id),
  
  -- Contract identification
  name TEXT NOT NULL,
  status service_contract_status DEFAULT 'draft',
  
  -- Term and renewal
  start_date DATE NOT NULL,
  end_date DATE,
  auto_renew BOOLEAN DEFAULT false,
  
  -- Billing configuration
  billing_frequency contract_billing_frequency DEFAULT 'annual',
  base_fee NUMERIC(10,2) DEFAULT 0,
  
  -- Snapshotted pricing from plan (at contract creation)
  labor_rate_type labor_rate_type DEFAULT 'standard',
  labor_discount_percent NUMERIC(5,2) DEFAULT 0,
  labor_fixed_rate NUMERIC(10,2),
  parts_discount_percent NUMERIC(5,2) DEFAULT 0,
  trip_charge_discount_percent NUMERIC(5,2) DEFAULT 0,
  waive_trip_charge BOOLEAN DEFAULT false,
  
  -- Snapshotted coverage from plan
  includes_emergency_service BOOLEAN DEFAULT false,
  includes_after_hours_rate_reduction BOOLEAN DEFAULT false,
  included_visits_per_year INTEGER DEFAULT 0,
  priority_level priority_level DEFAULT 'normal',
  response_time_sla_hours NUMERIC(6,2),
  
  -- Usage tracking
  visits_used_current_term INTEGER DEFAULT 0,
  last_renewed_at TIMESTAMPTZ,
  
  -- Billing tracking
  next_billing_date DATE,
  last_billed_date DATE,
  
  -- Additional info
  notes TEXT,
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES profiles(id),
  updated_by UUID REFERENCES profiles(id)
);

-- Enable RLS
ALTER TABLE service_contracts ENABLE ROW LEVEL SECURITY;

-- Policies for service_contracts
CREATE POLICY "Authenticated users can view service contracts"
  ON service_contracts FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins and dispatchers can insert service contracts"
  ON service_contracts FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Admins and dispatchers can update service contracts"
  ON service_contracts FOR UPDATE
  TO authenticated
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

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_service_contracts_customer ON service_contracts(customer_id);
CREATE INDEX IF NOT EXISTS idx_service_contracts_location ON service_contracts(customer_location_id) WHERE customer_location_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_service_contracts_plan ON service_contracts(contract_plan_id);
CREATE INDEX IF NOT EXISTS idx_service_contracts_status ON service_contracts(status);
CREATE INDEX IF NOT EXISTS idx_service_contracts_active_dates ON service_contracts(start_date, end_date) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_service_contracts_next_billing ON service_contracts(next_billing_date) WHERE next_billing_date IS NOT NULL AND status = 'active';

-- Update trigger for service_contracts
CREATE OR REPLACE FUNCTION update_service_contracts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS service_contracts_updated_at ON service_contracts;
CREATE TRIGGER service_contracts_updated_at
  BEFORE UPDATE ON service_contracts
  FOR EACH ROW
  EXECUTE FUNCTION update_service_contracts_updated_at();
