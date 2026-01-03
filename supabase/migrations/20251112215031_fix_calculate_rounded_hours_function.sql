/*
  # Fix calculate_rounded_hours Function

  1. Changes
    - Remove invalid 'assigned' status reference (not part of ticket_status enum)
    - The function should only track 'in_progress' start time and 'completed' end time
    - Remove accepted_at tracking since that doesn't apply to the current workflow
  
  2. Notes
    - Valid ticket statuses are: 'open', 'scheduled', 'in_progress', 'completed', 'cancelled'
    - This fixes the "invalid input value for enum ticket_status: 'assigned'" error
*/

CREATE OR REPLACE FUNCTION calculate_rounded_hours()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_duration_minutes numeric;
  v_rounded_hours numeric;
BEGIN
  -- Track start time when ticket moves to in_progress
  IF NEW.status = 'in_progress' AND (OLD.status IS NULL OR OLD.status != 'in_progress') AND NEW.started_at IS NULL THEN
    NEW.started_at := NOW();
  END IF;

  -- Track completion time and calculate hours when ticket is completed
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    NEW.completed_at := NOW();
    
    -- Calculate duration if we have start time
    IF NEW.started_at IS NOT NULL THEN
      -- Calculate total minutes
      v_duration_minutes := EXTRACT(EPOCH FROM (NEW.completed_at - NEW.started_at)) / 60.0;
      NEW.actual_duration_minutes := v_duration_minutes;
      
      -- Round UP to nearest 15 minutes and convert to hours
      -- CEIL(minutes / 15) * 15 gives us rounded minutes
      -- Then divide by 60 to get hours
      v_rounded_hours := (CEIL(v_duration_minutes / 15.0) * 15.0) / 60.0;
      
      -- Update hours_onsite with rounded value
      NEW.hours_onsite := v_rounded_hours;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
