/*
  # Add Vendor Contract Number Auto-Generation

  1. Function & Trigger
    - Create `generate_vendor_contract_number` function
    - Generates unique contract numbers like VC-2025-0001
    - Auto-assigns on INSERT if contract_number is NULL

  2. Important Notes
    - Uses advisory locks to prevent race conditions
    - Format: VC-{YEAR}-{SEQUENCE}
    - Sequence resets each year
*/

-- =====================================================
-- CONTRACT NUMBER GENERATION
-- =====================================================

-- Function to generate the next vendor contract number
CREATE OR REPLACE FUNCTION generate_vendor_contract_number()
RETURNS TEXT AS $$
DECLARE
  next_num INTEGER;
  year_str TEXT;
  contract_num TEXT;
BEGIN
  -- Use advisory lock to prevent race conditions
  PERFORM pg_advisory_xact_lock(hashtext('vendor_contract_number_seq'));
  
  year_str := TO_CHAR(CURRENT_DATE, 'YYYY');
  
  -- Get the highest contract number for the current year
  SELECT COALESCE(
    MAX(
      CAST(
        SUBSTRING(contract_number FROM 'VC-' || year_str || '-(\d+)') 
        AS INTEGER
      )
    ),
    0
  ) + 1
  INTO next_num
  FROM vendor_contracts
  WHERE contract_number LIKE 'VC-' || year_str || '-%';
  
  -- Generate the new contract number
  contract_num := 'VC-' || year_str || '-' || LPAD(next_num::TEXT, 4, '0');
  
  RETURN contract_num;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate contract number on insert
CREATE OR REPLACE FUNCTION set_vendor_contract_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.contract_number IS NULL OR NEW.contract_number = '' THEN
    NEW.contract_number := generate_vendor_contract_number();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS vendor_contract_number_trigger ON vendor_contracts;
CREATE TRIGGER vendor_contract_number_trigger
  BEFORE INSERT ON vendor_contracts
  FOR EACH ROW
  EXECUTE FUNCTION set_vendor_contract_number();
