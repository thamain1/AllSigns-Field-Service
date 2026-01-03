/*
  # Add automatic vendor code generation

  1. Changes
    - Create a function to generate unique vendor codes
    - Add a trigger to auto-generate vendor_code on insert if not provided
    - Make vendor_code have a default value
  
  2. Notes
    - Vendor codes will be in format: VEN-XXXXX (5 digit sequential number)
    - Existing vendors without codes will need to be updated separately
*/

-- Create sequence for vendor codes
CREATE SEQUENCE IF NOT EXISTS vendor_code_seq START WITH 10000;

-- Create function to generate vendor code
CREATE OR REPLACE FUNCTION generate_vendor_code()
RETURNS TEXT AS $$
DECLARE
  new_code TEXT;
  code_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate code in format VEN-XXXXX
    new_code := 'VEN-' || LPAD(nextval('vendor_code_seq')::TEXT, 5, '0');
    
    -- Check if code already exists
    SELECT EXISTS(SELECT 1 FROM vendors WHERE vendor_code = new_code) INTO code_exists;
    
    -- If code doesn't exist, return it
    IF NOT code_exists THEN
      RETURN new_code;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create trigger function to auto-generate vendor_code
CREATE OR REPLACE FUNCTION set_vendor_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.vendor_code IS NULL OR NEW.vendor_code = '' THEN
    NEW.vendor_code := generate_vendor_code();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS ensure_vendor_code ON vendors;
CREATE TRIGGER ensure_vendor_code
  BEFORE INSERT ON vendors
  FOR EACH ROW
  EXECUTE FUNCTION set_vendor_code();
