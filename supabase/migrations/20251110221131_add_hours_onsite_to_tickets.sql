/*
  # Add Hours Onsite Tracking to Tickets
  
  Adds field to track time spent on-site for service calls to enable:
  - Average time calculation per service type
  - Predictive scheduling and estimation
  - Better resource allocation
  
  ## Changes
  
  1. **Tickets Table Modifications**
     - Add `hours_onsite` column (numeric, nullable)
       - Allows decimal values (e.g., 2.5 hours)
       - Nullable as it's filled after service completion
       - Default NULL for new tickets
  
  ## Usage Notes
  - Hours onsite captured when ticket is completed
  - Used to calculate average time per service type
  - Enables predictive scheduling for future tickets
*/

-- Add hours_onsite column to tickets table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'hours_onsite'
  ) THEN
    ALTER TABLE tickets ADD COLUMN hours_onsite NUMERIC(5,2);
    COMMENT ON COLUMN tickets.hours_onsite IS 'Time spent on-site in hours (supports decimals)';
  END IF;
END $$;
