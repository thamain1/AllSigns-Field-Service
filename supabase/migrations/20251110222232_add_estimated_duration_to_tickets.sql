/*
  # Add estimated duration to tickets

  1. Changes
    - Add `estimated_duration` column to `tickets` table
      - Type: integer (duration in minutes)
      - Default: 120 (2 hours)
      - Not null
  
  2. Notes
    - Estimated duration helps with scheduling and drag-drop board visualization
    - Default of 120 minutes (2 hours) is a reasonable estimate for service calls
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'estimated_duration'
  ) THEN
    ALTER TABLE tickets ADD COLUMN estimated_duration integer NOT NULL DEFAULT 120;
  END IF;
END $$;