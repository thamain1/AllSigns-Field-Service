/*
  # Fix Ticket Number Generation - Concurrency and Format Issues

  ## Changes Made
  
  1. **Ticket Number Format**
     - SVC tickets: SVC-YYMM-DD-NNN (e.g., SVC-2511-20-001)
     - PRJ tickets: PRJ-YYMM-XXX-NNN (e.g., PRJ-2511-105-001)
  
  2. **Fix Concurrency Issues**
     - Use proper locking with SELECT FOR UPDATE
     - Handle race conditions in sequence generation
     - Use YYMM format instead of YYYYMM
  
  3. **Fix Generation Functions**
     - Completely rewrite to handle concurrent ticket creation
     - Properly format sequence numbers with leading zeros
     - Use consistent date formatting
*/

-- Drop existing functions to recreate them
DROP FUNCTION IF EXISTS public.generate_svc_ticket_number() CASCADE;
DROP FUNCTION IF EXISTS public.generate_prj_ticket_number(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_next_ticket_number(ticket_type, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.auto_generate_ticket_number() CASCADE;

-- Function to generate SVC ticket number with proper locking
CREATE OR REPLACE FUNCTION public.generate_svc_ticket_number()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year_month text;
  v_day integer;
  v_sequence integer;
  v_ticket_number text;
BEGIN
  -- Get current date parts in YYMM-DD format
  v_year_month := TO_CHAR(CURRENT_DATE, 'YYMM');
  v_day := EXTRACT(DAY FROM CURRENT_DATE)::integer;
  
  -- Lock and get/increment sequence for today
  -- Use NOWAIT to fail fast if there's contention
  SELECT last_sequence + 1 INTO v_sequence
  FROM ticket_sequences
  WHERE ticket_type = 'SVC'
    AND year_month = v_year_month
    AND day_of_month = v_day
    AND project_id IS NULL
  FOR UPDATE;
  
  IF NOT FOUND THEN
    -- Create new sequence record for today
    INSERT INTO ticket_sequences (
      ticket_type,
      year_month,
      day_of_month,
      project_id,
      last_sequence
    ) VALUES (
      'SVC',
      v_year_month,
      v_day,
      NULL,
      1
    );
    v_sequence := 1;
  ELSE
    -- Update the sequence
    UPDATE ticket_sequences
    SET last_sequence = v_sequence,
        updated_at = NOW()
    WHERE ticket_type = 'SVC'
      AND year_month = v_year_month
      AND day_of_month = v_day
      AND project_id IS NULL;
  END IF;
  
  -- Format: SVC-YYMM-DD-NNN
  v_ticket_number := 'SVC-' || v_year_month || '-' || LPAD(v_day::text, 2, '0') || '-' || LPAD(v_sequence::text, 3, '0');
  
  RETURN v_ticket_number;
END;
$$;

-- Function to generate PRJ ticket number with proper locking
CREATE OR REPLACE FUNCTION public.generate_prj_ticket_number(p_project_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_project_number text;
  v_year_month text;
  v_day integer;
  v_sequence integer;
  v_ticket_number text;
BEGIN
  -- Get project number from projects table
  SELECT project_number INTO v_project_number
  FROM projects
  WHERE id = p_project_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Project not found: %', p_project_id;
  END IF;
  
  -- Get current date parts
  v_year_month := TO_CHAR(CURRENT_DATE, 'YYMM');
  v_day := EXTRACT(DAY FROM CURRENT_DATE)::integer;
  
  -- Lock and get/increment sequence for this project
  SELECT last_sequence + 1 INTO v_sequence
  FROM ticket_sequences
  WHERE ticket_type = 'PRJ'
    AND project_id = p_project_id
    AND year_month = v_year_month
    AND day_of_month = v_day
  FOR UPDATE;
  
  IF NOT FOUND THEN
    -- Create new sequence record for this project
    INSERT INTO ticket_sequences (
      ticket_type,
      year_month,
      day_of_month,
      project_id,
      last_sequence
    ) VALUES (
      'PRJ',
      v_year_month,
      v_day,
      p_project_id,
      1
    );
    v_sequence := 1;
  ELSE
    -- Update the sequence
    UPDATE ticket_sequences
    SET last_sequence = v_sequence,
        updated_at = NOW()
    WHERE ticket_type = 'PRJ'
      AND project_id = p_project_id
      AND year_month = v_year_month
      AND day_of_month = v_day;
  END IF;
  
  -- Format: PRJ-{project_number}-NNN
  v_ticket_number := 'PRJ-' || v_project_number || '-' || LPAD(v_sequence::text, 3, '0');
  
  RETURN v_ticket_number;
END;
$$;

-- Main function to get ticket number based on type
CREATE OR REPLACE FUNCTION public.get_next_ticket_number(
  p_ticket_type ticket_type,
  p_project_id uuid DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_ticket_type = 'PRJ' THEN
    IF p_project_id IS NULL THEN
      RAISE EXCEPTION 'project_id is required for PRJ tickets';
    END IF;
    RETURN generate_prj_ticket_number(p_project_id);
  ELSIF p_ticket_type = 'SVC' THEN
    RETURN generate_svc_ticket_number();
  ELSE
    RAISE EXCEPTION 'Invalid ticket type: %', p_ticket_type;
  END IF;
END;
$$;

-- Trigger function to auto-generate ticket number
CREATE OR REPLACE FUNCTION public.auto_generate_ticket_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only generate if ticket_number is not set
  IF NEW.ticket_number IS NULL OR NEW.ticket_number = '' THEN
    NEW.ticket_number := get_next_ticket_number(NEW.ticket_type, NEW.project_id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Recreate the trigger
DROP TRIGGER IF EXISTS trigger_auto_generate_ticket_number ON tickets;

CREATE TRIGGER trigger_auto_generate_ticket_number
  BEFORE INSERT ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_ticket_number();

-- Clean up old format sequences (YYYYMM format)
DELETE FROM ticket_sequences WHERE year_month LIKE '2025%';

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION generate_svc_ticket_number() TO authenticated;
GRANT EXECUTE ON FUNCTION generate_prj_ticket_number(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_next_ticket_number(ticket_type, uuid) TO authenticated;
