/*
  # Fix generate_estimate_number Function

  ## Overview
  This migration fixes the generate_estimate_number() function that was incorrectly
  modified in the fix_search_paths_cascade migration. The function was changed to use
  columns (id integer, next_number) that don't exist in the estimate_sequences table.

  ## Changes Made
  1. Restore the correct generate_estimate_number() function that uses:
     - year_month (text)
     - day_of_month (integer)
     - last_sequence (integer)
  2. Maintains the EST-YYMM-DD-N format (e.g., EST-2512-13-1)

  ## Issue Fixed
  - Function was trying to access `next_number` column that doesn't exist
  - Function was trying to use `id = 1` (integer) but id is UUID
  - This was preventing any estimates from being created
*/

CREATE OR REPLACE FUNCTION generate_estimate_number()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_year_month text;
  v_day text;
  v_day_int integer;
  v_sequence integer;
BEGIN
  -- Get current date parts
  v_year_month := to_char(now(), 'YYMM');
  v_day := to_char(now(), 'DD');
  v_day_int := EXTRACT(DAY FROM now())::integer;
  
  -- Get next sequence number for today
  INSERT INTO estimate_sequences (year_month, day_of_month, last_sequence)
  VALUES (v_year_month, v_day_int, 1)
  ON CONFLICT (year_month, day_of_month)
  DO UPDATE SET 
    last_sequence = estimate_sequences.last_sequence + 1,
    updated_at = now()
  RETURNING last_sequence INTO v_sequence;
  
  -- Return formatted estimate number: EST-YYMM-DD-N
  RETURN 'EST-' || v_year_month || '-' || v_day || '-' || v_sequence;
END;
$$;
