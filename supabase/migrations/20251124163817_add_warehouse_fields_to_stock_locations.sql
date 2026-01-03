/*
  # Add warehouse location fields to stock_locations
  
  1. Changes
    - Add `vehicle_id` column to track vehicle assignments
    - Add `technician_id` column to track technician assignments (references profiles)
    - Update existing stock_locations with data from warehouse_locations where names match
  
  2. Notes
    - Preserves all existing functionality
    - Maintains backward compatibility
    - Does not drop warehouse_locations table (kept for reference)
*/

-- Add vehicle_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'stock_locations' AND column_name = 'vehicle_id'
  ) THEN
    ALTER TABLE stock_locations ADD COLUMN vehicle_id text;
  END IF;
END $$;

-- Add technician_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'stock_locations' AND column_name = 'technician_id'
  ) THEN
    ALTER TABLE stock_locations ADD COLUMN technician_id uuid REFERENCES profiles(id);
  END IF;
END $$;

-- Migrate data from warehouse_locations to stock_locations based on matching names
UPDATE stock_locations sl
SET 
  vehicle_id = wl.vehicle_id,
  technician_id = wl.technician_id,
  address = COALESCE(sl.address, wl.address)
FROM warehouse_locations wl
WHERE sl.name = wl.name 
  AND wl.is_active = true;