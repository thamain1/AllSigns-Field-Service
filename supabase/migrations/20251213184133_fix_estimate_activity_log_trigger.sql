/*
  # Fix Estimate Activity Log Trigger
  
  1. Changes
    - Fix trigger function to use correct column name 'action' instead of 'action_type'
    - Fix to handle case when updated_by is NULL
  
  2. Purpose
    - Fixes estimate status changes that were failing due to column name mismatch
    - Ensures activity logging works correctly
*/

CREATE OR REPLACE FUNCTION trigger_log_estimate_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- Only log if status actually changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO estimate_activity_log (
      estimate_id, 
      action, 
      description, 
      old_status,
      new_status,
      performed_by
    ) VALUES (
      NEW.id, 
      'status_change', 
      'Status changed from ' || OLD.status || ' to ' || NEW.status,
      OLD.status,
      NEW.status,
      COALESCE(auth.uid(), NEW.created_by)
    );
  END IF;
  
  RETURN NEW;
END;
$$;
