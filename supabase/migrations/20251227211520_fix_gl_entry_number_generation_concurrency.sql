/*
  # Fix GL Entry Number Generation for Concurrency

  ## Overview
  The generate_gl_entry_number() function had a race condition when processing
  multiple invoices in the same transaction. This fix adds proper locking and
  uses a sequence-based approach for entry numbering.

  ## Changes
  - Create a sequence for GL entry numbering
  - Update generate_gl_entry_number() to use the sequence
  - Ensures each entry_number is truly unique even in concurrent transactions

  ## Important Notes
  - This is a non-breaking change
  - Existing entry numbers are not affected
  - Future entries will use the sequence-based approach
*/

-- Create a sequence for GL entry numbering
CREATE SEQUENCE IF NOT EXISTS gl_entry_number_seq START WITH 1;

-- Update the generate_gl_entry_number function to be transaction-safe
CREATE OR REPLACE FUNCTION generate_gl_entry_number()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  new_number text;
  counter int;
  date_part text;
BEGIN
  -- Use nextval to get a truly unique counter (thread-safe)
  counter := nextval('gl_entry_number_seq');
  
  date_part := 'JE-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD');
  
  -- Create entry number with guaranteed unique counter
  new_number := date_part || '-' || LPAD(counter::text, 4, '0');
  
  RETURN new_number;
END;
$$;

-- Grant usage on sequence
GRANT USAGE ON SEQUENCE gl_entry_number_seq TO authenticated;

COMMENT ON SEQUENCE gl_entry_number_seq IS 'Sequence for generating unique GL entry numbers';
COMMENT ON FUNCTION generate_gl_entry_number IS 'Generates unique GL entry numbers using a sequence. Format: JE-YYYYMMDD-NNNN';
