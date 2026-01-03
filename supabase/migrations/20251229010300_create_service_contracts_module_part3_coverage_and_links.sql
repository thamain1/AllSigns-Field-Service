/*
  # Create Service Contracts Module - Part 3: Coverage & Links

  1. New Tables
    - `service_contract_coverage` - Equipment/systems covered by contracts
      - Links to service contract
      - Coverage type (entire site, specific equipment, system, zone)
      - Optional equipment link for specific coverage
      - Coverage limits and levels

  2. Schema Changes (Additive Only)
    - Add `service_contract_id` to tickets table (nullable FK)
    - Add `service_contract_id` to estimates table (nullable FK)
    - Add `service_contract_id` to invoices table (nullable FK)

  3. New Enums
    - `coverage_type` - Type of coverage (site, equipment, system, zone)

  4. Security
    - Enable RLS on service_contract_coverage
    - Policies for authenticated users

  5. Important Notes
    - ALL changes are additive - no existing columns modified
    - FK columns are nullable to preserve existing data
    - Existing workflows continue unchanged for non-contract cases
*/

-- Create enum for coverage type
DO $$ BEGIN
  CREATE TYPE coverage_type AS ENUM (
    'entire_site',
    'equipment',
    'system',
    'zone'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Service Contract Coverage table (what's covered)
CREATE TABLE IF NOT EXISTS service_contract_coverage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Link to contract
  service_contract_id UUID NOT NULL REFERENCES service_contracts(id) ON DELETE CASCADE,
  
  -- Coverage type and scope
  coverage_type coverage_type DEFAULT 'entire_site',
  equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
  equipment_group TEXT,
  system_tag TEXT,
  
  -- Coverage limits
  max_visits_per_year_for_item INTEGER,
  parts_coverage_level parts_coverage_level DEFAULT 'limited',
  labor_coverage_level labor_coverage_level DEFAULT 'discount_only',
  
  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE service_contract_coverage ENABLE ROW LEVEL SECURITY;

-- Policies for service_contract_coverage
CREATE POLICY "Authenticated users can view contract coverage"
  ON service_contract_coverage FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins and dispatchers can manage contract coverage"
  ON service_contract_coverage FOR ALL
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
CREATE INDEX IF NOT EXISTS idx_contract_coverage_contract ON service_contract_coverage(service_contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_coverage_equipment ON service_contract_coverage(equipment_id) WHERE equipment_id IS NOT NULL;

-- Add service_contract_id to tickets (nullable, additive only)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets'
      AND column_name = 'service_contract_id'
  ) THEN
    ALTER TABLE tickets
      ADD COLUMN service_contract_id UUID NULL REFERENCES service_contracts(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add service_contract_id to estimates (nullable, additive only)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'estimates'
      AND column_name = 'service_contract_id'
  ) THEN
    ALTER TABLE estimates
      ADD COLUMN service_contract_id UUID NULL REFERENCES service_contracts(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add service_contract_id to invoices (nullable, additive only)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices'
      AND column_name = 'service_contract_id'
  ) THEN
    ALTER TABLE invoices
      ADD COLUMN service_contract_id UUID NULL REFERENCES service_contracts(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Indexes for contract links on core tables
CREATE INDEX IF NOT EXISTS idx_tickets_service_contract ON tickets(service_contract_id) WHERE service_contract_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_estimates_service_contract ON estimates(service_contract_id) WHERE service_contract_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_invoices_service_contract ON invoices(service_contract_id) WHERE service_contract_id IS NOT NULL;
