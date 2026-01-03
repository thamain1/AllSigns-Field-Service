/*
  # Add quantity_damaged column to purchase_order_lines

  1. Changes
    - Add `quantity_damaged` column to track damaged items during receiving
    - Set default value to 0
    - Add check constraint to ensure quantity_damaged >= 0

  2. Notes
    - This column tracks the number of damaged items received
    - Used during the parts receiving process
*/

-- Add quantity_damaged column
ALTER TABLE purchase_order_lines 
ADD COLUMN IF NOT EXISTS quantity_damaged numeric(10,2) DEFAULT 0 CHECK (quantity_damaged >= 0);
