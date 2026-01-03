/*
  # Add photo_type Column to ticket_photos

  1. Changes
    - Add photo_type column to ticket_photos table
    - Type can be 'before', 'during', or 'after'
    - Defaults to 'during'
  
  2. Notes
    - This allows technicians to categorize photos by when they were taken
*/

-- Add photo_type column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'ticket_photos' AND column_name = 'photo_type'
  ) THEN
    ALTER TABLE ticket_photos 
    ADD COLUMN photo_type text DEFAULT 'during' CHECK (photo_type IN ('before', 'during', 'after'));
  END IF;
END $$;
