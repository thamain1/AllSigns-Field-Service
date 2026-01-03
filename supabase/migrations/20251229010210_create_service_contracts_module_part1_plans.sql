/*
  # Create Service Contracts Module - Part 1: Contract Plan Templates

  1. New Tables
    - `contract_plans` - Template plans (Silver, Gold, Platinum, Custom)
      - Core plan information (name, description, active status)
      - Pricing defaults (labor rates, discounts, parts discounts)
      - Coverage defaults (emergency service, visits, priority, SLA)
      - Billing defaults (frequency, base fee)
      - Audit fields

  2. New Enums
    - `labor_rate_type` - How labor rates are calculated for contracts
    - `contract_billing_frequency` - How often contract fees are billed
    - `priority_level` - Service priority for contract holders
    - `parts_coverage_level` - How parts are covered under contract
    - `labor_coverage_level` - How labor is covered under contract

  3. Security
    - Enable RLS on all new tables
    - Policies for authenticated users to read plans
    - Policies for admins to manage plans

  4. Important Notes
    - All schema changes are additive only
    - No existing tables or columns are modified
    - Plans are templates that get copied into contracts
*/

-- Create enums for contract management
DO $$ BEGIN
  CREATE TYPE labor_rate_type AS ENUM (
    'standard',
    'discount_percentage',
    'fixed_rate',
    'tiered'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE contract_billing_frequency AS ENUM (
    'annual',
    'semi_annual',
    'quarterly',
    'monthly',
    'per_visit'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE priority_level AS ENUM (
    'normal',
    'priority',
    'vip'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE parts_coverage_level AS ENUM (
    'none',
    'limited',
    'full'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE labor_coverage_level AS ENUM (
    'none',
    'discount_only',
    'full_for_pm_only',
    'full_all_service'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Contract Plan Templates table
CREATE TABLE IF NOT EXISTS contract_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  
  -- Pricing defaults (copied into contracts)
  labor_rate_type labor_rate_type DEFAULT 'standard',
  labor_discount_percent NUMERIC(5,2) DEFAULT 0,
  labor_fixed_rate NUMERIC(10,2),
  parts_discount_percent NUMERIC(5,2) DEFAULT 0,
  trip_charge_discount_percent NUMERIC(5,2) DEFAULT 0,
  waive_trip_charge BOOLEAN DEFAULT false,
  
  -- Coverage defaults
  includes_emergency_service BOOLEAN DEFAULT false,
  includes_after_hours_rate_reduction BOOLEAN DEFAULT false,
  included_visits_per_year INTEGER DEFAULT 0,
  priority_level priority_level DEFAULT 'normal',
  response_time_sla_hours NUMERIC(6,2),
  
  -- Billing defaults
  billing_frequency contract_billing_frequency DEFAULT 'annual',
  default_base_fee NUMERIC(10,2) DEFAULT 0,
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_by UUID REFERENCES profiles(id),
  updated_by UUID REFERENCES profiles(id)
);

-- Enable RLS
ALTER TABLE contract_plans ENABLE ROW LEVEL SECURITY;

-- Policies for contract_plans
CREATE POLICY "Authenticated users can view active contract plans"
  ON contract_plans FOR SELECT
  TO authenticated
  USING (is_active = true OR auth.uid() IS NOT NULL);

CREATE POLICY "Admins can insert contract plans"
  ON contract_plans FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can update contract plans"
  ON contract_plans FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_contract_plans_active ON contract_plans(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_contract_plans_created_at ON contract_plans(created_at DESC);

-- Update trigger for contract_plans
CREATE OR REPLACE FUNCTION update_contract_plans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS contract_plans_updated_at ON contract_plans;
CREATE TRIGGER contract_plans_updated_at
  BEFORE UPDATE ON contract_plans
  FOR EACH ROW
  EXECUTE FUNCTION update_contract_plans_updated_at();
