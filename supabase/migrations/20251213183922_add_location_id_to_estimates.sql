/*
  # Add Location ID to Estimates
  
  1. Changes
    - Add nullable location_id column to estimates table
    - Add foreign key to customer_locations table
    - Preserve existing site_location text field for backward compatibility
  
  2. Purpose
    - Properly link estimates to customer locations
    - Enable location-based filtering and reporting
    - Support multi-location customers
    - Maintain existing data integrity
*/

-- Add location_id column (nullable to be non-destructive)
ALTER TABLE estimates 
ADD COLUMN IF NOT EXISTS location_id uuid REFERENCES customer_locations(id);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_estimates_location_id ON estimates(location_id);
