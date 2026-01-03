/*
  # Automatic Time Tracking for Service Tickets

  ## Overview
  Adds automatic time tracking to tickets based on status changes.
  Calculates total job time rounded up to 15-minute increments when tickets are completed.

  ## 1. New Columns Added to tickets table
    - `accepted_at` (timestamptz) - When technician accepts ticket
    - `started_at` (timestamptz) - When work begins (status -> in_progress)
    - `completed_at` (timestamptz) - When work is completed
    - `actual_duration_minutes` (numeric) - Calculated time between started_at and completed_at

  ## 2. Function: calculate_rounded_hours()
    - Calculates duration between started_at and completed_at
    - Rounds UP to nearest 15-minute increment
    - Updates hours_onsite field automatically
    - Formula: CEIL(minutes / 15) * 0.25 hours

  ## 3. Trigger: auto_track_ticket_times
    - Tracks when ticket is accepted (status -> assigned)
    - Tracks when work starts (status -> in_progress)
    - Tracks when work completes (status -> completed)
    - Automatically calculates and sets hours_onsite on completion

  ## 4. Time Tracking Logic
    - **Accepted**: Records timestamp when technician accepts
    - **Started**: Records timestamp when status changes to in_progress
    - **Completed**: Records timestamp and calculates duration
    - **Duration**: Time from started_at to completed_at
    - **Rounding**: Always rounds UP to next 15-minute interval

  ## 5. Examples
    - 1 hour 5 minutes → 1.25 hours (1h 15m)
    - 2 hours 20 minutes → 2.5 hours (2h 30m)
    - 45 minutes → 0.75 hours (45m)
    - 50 minutes → 1.0 hours (1h 0m)
    - 3 hours 46 minutes → 4.0 hours (4h 0m)

  ## 6. Benefits
    - Accurate time tracking
    - Consistent billing intervals
    - No manual time entry needed
    - Fair rounding for both company and customer
*/

-- Add time tracking columns to tickets table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'accepted_at'
  ) THEN
    ALTER TABLE tickets ADD COLUMN accepted_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'started_at'
  ) THEN
    ALTER TABLE tickets ADD COLUMN started_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'completed_at'
  ) THEN
    ALTER TABLE tickets ADD COLUMN completed_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'actual_duration_minutes'
  ) THEN
    ALTER TABLE tickets ADD COLUMN actual_duration_minutes numeric DEFAULT 0;
  END IF;
END $$;

-- Function to calculate rounded hours from time tracking
CREATE OR REPLACE FUNCTION calculate_rounded_hours()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_duration_minutes numeric;
  v_rounded_hours numeric;
BEGIN
  -- Track accepted time
  IF NEW.status = 'assigned' AND OLD.status != 'assigned' AND NEW.accepted_at IS NULL THEN
    NEW.accepted_at := NOW();
  END IF;

  -- Track start time
  IF NEW.status = 'in_progress' AND (OLD.status IS NULL OR OLD.status != 'in_progress') AND NEW.started_at IS NULL THEN
    NEW.started_at := NOW();
  END IF;

  -- Track completion time and calculate hours
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

-- Create trigger for automatic time tracking
DROP TRIGGER IF EXISTS auto_track_ticket_times ON tickets;

CREATE TRIGGER auto_track_ticket_times
  BEFORE UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION calculate_rounded_hours();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION calculate_rounded_hours() TO authenticated;

-- Add helpful comments
COMMENT ON COLUMN tickets.accepted_at IS 'Timestamp when technician accepted the ticket';
COMMENT ON COLUMN tickets.started_at IS 'Timestamp when technician started work (status -> in_progress)';
COMMENT ON COLUMN tickets.completed_at IS 'Timestamp when ticket was marked completed';
COMMENT ON COLUMN tickets.actual_duration_minutes IS 'Actual duration in minutes before rounding';
COMMENT ON COLUMN tickets.hours_onsite IS 'Billable hours (rounded up to nearest 15 minutes)';
