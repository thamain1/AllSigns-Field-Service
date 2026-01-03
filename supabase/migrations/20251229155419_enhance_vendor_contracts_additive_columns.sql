/*
  # Enhance Existing Vendor Contracts - Additive Columns Only

  1. Additive Columns to vendor_contracts
    - Add missing commercial terms fields
    - Add lead time tracking
    - Add freight and minimum order fields
    - All new columns are nullable to preserve existing data

  2. Important Notes
    - NO destructive changes
    - Existing vendor_contracts records remain intact
    - New columns default to NULL
    - Uses TEXT for status/type to match existing schema
*/

-- =====================================================
-- ADD MISSING COLUMNS TO EXISTING vendor_contracts
-- =====================================================

-- Add freight and order minimums
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'freight_terms'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN freight_terms text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'minimum_order_value'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN minimum_order_value numeric(10, 2);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'free_freight_threshold'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN free_freight_threshold numeric(10, 2);
  END IF;
END $$;

-- Add lead time tracking
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'standard_lead_time_days'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN standard_lead_time_days integer;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'rush_lead_time_days'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN rush_lead_time_days integer;
  END IF;
END $$;

-- Add warranty and return policy
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'return_policy'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN return_policy text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'warranty_terms'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN warranty_terms text;
  END IF;
END $$;

-- Add preferred vendor flag
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'is_preferred_vendor'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN is_preferred_vendor boolean DEFAULT false;
  END IF;
END $$;

-- Add renewal term for auto-renew contracts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'renewal_term_months'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN renewal_term_months integer;
  END IF;
END $$;

-- Add audit tracking for who last updated
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'vendor_contracts' AND column_name = 'updated_by_user_id'
  ) THEN
    ALTER TABLE vendor_contracts ADD COLUMN updated_by_user_id uuid REFERENCES profiles(id);
  END IF;
END $$;

-- Create indexes for new columns if they don't exist
CREATE INDEX IF NOT EXISTS idx_vendor_contracts_vendor_status 
  ON vendor_contracts(vendor_id, status);
  
CREATE INDEX IF NOT EXISTS idx_vendor_contracts_dates_status 
  ON vendor_contracts(start_date, end_date, status);

CREATE INDEX IF NOT EXISTS idx_vendor_contracts_preferred 
  ON vendor_contracts(vendor_id, is_preferred_vendor) 
  WHERE is_preferred_vendor = true;
