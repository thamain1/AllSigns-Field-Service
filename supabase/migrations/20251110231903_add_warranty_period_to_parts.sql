/*
  # Add OEM Warranty Period to Parts

  1. Changes
    - Add `warranty_period_months` column to `parts` table
      - Integer field to store warranty period in months
      - Nullable to allow parts without warranty
      - Default value of NULL
  
  2. Notes
    - This allows tracking of manufacturer warranty periods for parts
    - Can be used to determine if a part is still under warranty when used
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'parts' AND column_name = 'warranty_period_months'
  ) THEN
    ALTER TABLE parts ADD COLUMN warranty_period_months integer DEFAULT NULL;
  END IF;
END $$;