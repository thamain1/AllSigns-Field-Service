/*
  # Fix Ticket Number Generation Functions

  1. Changes
    - Fix generate_prj_ticket_number to use last_sequence instead of next_number
    - Fix generate_svc_ticket_number to use last_sequence instead of next_number
    - Update logic to work with the actual ticket_sequences table structure
    
  2. Notes
    - The ticket_sequences table has last_sequence column, not next_number
    - Functions were using the wrong column name causing ticket creation to fail
*/

-- Drop and recreate the PRJ ticket number generator
DROP FUNCTION IF EXISTS public.generate_prj_ticket_number(uuid);

CREATE FUNCTION public.generate_prj_ticket_number(proj_id uuid) 
RETURNS text 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public, pg_temp 
AS $$ 
DECLARE 
  next_num integer;
  proj_num text;
  current_date_key text;
  current_day integer;
BEGIN 
  -- Get project number
  SELECT project_number INTO proj_num 
  FROM public.projects 
  WHERE id = proj_id;
  
  -- Generate date key (YYYYMM format)
  current_date_key := TO_CHAR(CURRENT_DATE, 'YYYYMM');
  current_day := EXTRACT(DAY FROM CURRENT_DATE);
  
  -- Get or create sequence for this project and month
  SELECT last_sequence + 1 INTO next_num
  FROM public.ticket_sequences 
  WHERE project_id = proj_id 
    AND year_month = current_date_key
    AND day_of_month = current_day
  FOR UPDATE;
  
  IF NOT FOUND THEN 
    -- Create new sequence record
    INSERT INTO public.ticket_sequences (
      ticket_type, 
      year_month, 
      project_id, 
      day_of_month, 
      last_sequence
    ) 
    VALUES ('PRJ', current_date_key, proj_id, current_day, 1) 
    RETURNING 1 INTO next_num;
  ELSE 
    -- Update existing sequence
    UPDATE public.ticket_sequences 
    SET last_sequence = last_sequence + 1,
        updated_at = now()
    WHERE project_id = proj_id 
      AND year_month = current_date_key
      AND day_of_month = current_day;
  END IF;
  
  RETURN proj_num || '-' || LPAD(next_num::text, 3, '0');
END; 
$$;

-- Drop and recreate the SVC ticket number generator
DROP FUNCTION IF EXISTS public.generate_svc_ticket_number();

CREATE OR REPLACE FUNCTION public.generate_svc_ticket_number() 
RETURNS text 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public, pg_temp 
AS $$ 
DECLARE 
  next_num integer;
  current_date_key text;
  current_day integer;
BEGIN 
  -- Generate date key (YYYYMM format)
  current_date_key := TO_CHAR(CURRENT_DATE, 'YYYYMM');
  current_day := EXTRACT(DAY FROM CURRENT_DATE);
  
  -- Get or create sequence for SVC tickets for this month/day
  SELECT last_sequence + 1 INTO next_num
  FROM public.ticket_sequences 
  WHERE project_id IS NULL 
    AND year_month = current_date_key
    AND day_of_month = current_day
  FOR UPDATE;
  
  IF NOT FOUND THEN 
    -- Create new sequence record
    INSERT INTO public.ticket_sequences (
      ticket_type,
      year_month, 
      project_id, 
      day_of_month, 
      last_sequence
    ) 
    VALUES ('SVC', current_date_key, NULL, current_day, 1) 
    RETURNING 1 INTO next_num;
  ELSE 
    -- Update existing sequence
    UPDATE public.ticket_sequences 
    SET last_sequence = last_sequence + 1,
        updated_at = now()
    WHERE project_id IS NULL 
      AND year_month = current_date_key
      AND day_of_month = current_day;
  END IF;
  
  RETURN 'SVC-' || LPAD(next_num::text, 6, '0');
END; 
$$;
