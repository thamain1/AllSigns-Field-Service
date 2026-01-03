/*
  # Expand Ticket Photo Types

  This migration expands the allowed photo_type values for ticket_photos to include
  additional useful categories beyond just before/during/after.

  1. Changes
    - Drop existing photo_type check constraint
    - Add new constraint with expanded photo type options:
      - before: Photos taken before work starts
      - during: Photos taken during work
      - after: Photos taken after work is complete
      - issue: Photos showing problems or issues
      - equipment: Photos of equipment placards, labels, model numbers
      - other: Other miscellaneous photos

  2. Notes
    - This aligns the database constraint with the UI form options
    - Default value remains 'during' for backward compatibility
*/

-- Drop the existing check constraint
ALTER TABLE ticket_photos 
DROP CONSTRAINT IF EXISTS ticket_photos_photo_type_check;

-- Add new constraint with expanded photo types
ALTER TABLE ticket_photos 
ADD CONSTRAINT ticket_photos_photo_type_check 
CHECK (photo_type = ANY (ARRAY['before', 'during', 'after', 'issue', 'equipment', 'other']));
