/*
  # Create Vendor Contracts & Agreements Module - Part 1: Enums and Main Contracts Table

  1. New Enums
    - `vendor_contract_type` - Type of vendor agreement (pricing, service, warranty, etc.)
    - `vendor_contract_status` - Contract lifecycle status (draft, active, expired, etc.)
    - `contract_price_type` - How pricing is calculated (fixed, discount_percent, formula)
    - `pricing_basis` - Basis for pricing (list_price, standard_cost, etc.)
    - `contract_sla_metric` - Performance metrics (on_time_delivery, fill_rate, etc.)
    - `contract_document_type` - Type of document (signed_contract, msa, etc.)

  2. New Tables
    - `vendor_contracts`
      - Master contract header with commercial terms
      - Links to vendor, tracks status, dates, payment/freight terms
      - Includes lead times, minimums, and preferences

  3. Security
    - Enable RLS on all new tables
    - Procurement and admin roles can manage contracts
    - All authenticated users can view contracts (read-only for most)

  4. Important Notes
    - All changes are additive - no existing tables modified in this part
    - Contracts are optional - vendors work without them
    - FK to purchase_orders added in Part 2
*/

-- =====================================================
-- ENUMS
-- =====================================================

-- Vendor contract types
CREATE TYPE vendor_contract_type AS ENUM (
  'pricing',
  'service',
  'warranty',
  'rebate',
  'distribution',
  'msa',
  'other'
);

-- Vendor contract status
CREATE TYPE vendor_contract_status AS ENUM (
  'draft',
  'active',
  'expired',
  'terminated',
  'suspended'
);

-- Contract price calculation type
CREATE TYPE contract_price_type AS ENUM (
  'fixed',
  'discount_percent',
  'formula'
);

-- Pricing basis
CREATE TYPE pricing_basis AS ENUM (
  'list_price',
  'standard_cost',
  'market_index',
  'other'
);

-- Contract SLA metrics
CREATE TYPE contract_sla_metric AS ENUM (
  'on_time_delivery',
  'fill_rate',
  'quality_defect_rate',
  'invoice_accuracy',
  'response_time',
  'other'
);

-- Contract document types
CREATE TYPE contract_document_type AS ENUM (
  'signed_contract',
  'msa',
  'nda',
  'warranty',
  'pricing_sheet',
  'insurance',
  'w9',
  'other'
);

-- =====================================================
-- MAIN CONTRACTS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS vendor_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  
  -- Contract identification
  contract_name text NOT NULL,
  contract_type vendor_contract_type NOT NULL DEFAULT 'pricing',
  status vendor_contract_status NOT NULL DEFAULT 'draft',
  
  -- Term dates
  start_date date NOT NULL,
  end_date date,
  auto_renew boolean DEFAULT false,
  renewal_term_months integer,
  
  -- Commercial terms (snapshot at contract level)
  payment_terms text,
  freight_terms text,
  minimum_order_value numeric(10, 2),
  free_freight_threshold numeric(10, 2),
  standard_lead_time_days integer,
  rush_lead_time_days integer,
  return_policy text,
  warranty_terms text,
  
  -- Preferences
  is_preferred_vendor boolean DEFAULT false,
  
  -- Notes
  notes text,
  
  -- Audit fields
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  created_by_user_id uuid REFERENCES profiles(id),
  updated_by_user_id uuid REFERENCES profiles(id),
  
  -- Constraints
  CONSTRAINT valid_dates CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT valid_lead_times CHECK (rush_lead_time_days IS NULL OR standard_lead_time_days IS NULL OR rush_lead_time_days <= standard_lead_time_days)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_vendor_contracts_vendor_id ON vendor_contracts(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_contracts_status ON vendor_contracts(status);
CREATE INDEX IF NOT EXISTS idx_vendor_contracts_dates ON vendor_contracts(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_vendor_contracts_active_lookup ON vendor_contracts(vendor_id, status, start_date, end_date) 
  WHERE status = 'active';

-- =====================================================
-- RLS POLICIES
-- =====================================================

ALTER TABLE vendor_contracts ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view contracts
CREATE POLICY "Authenticated users can view vendor contracts"
  ON vendor_contracts
  FOR SELECT
  TO authenticated
  USING (true);

-- Admins and dispatchers can insert contracts
CREATE POLICY "Admins and dispatchers can insert vendor contracts"
  ON vendor_contracts
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'dispatcher')
    )
  );

-- Admins and dispatchers can update contracts
CREATE POLICY "Admins and dispatchers can update vendor contracts"
  ON vendor_contracts
  FOR UPDATE
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

-- Admins can delete contracts
CREATE POLICY "Admins can delete vendor contracts"
  ON vendor_contracts
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_vendor_contracts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER vendor_contracts_updated_at
  BEFORE UPDATE ON vendor_contracts
  FOR EACH ROW
  EXECUTE FUNCTION update_vendor_contracts_updated_at();
