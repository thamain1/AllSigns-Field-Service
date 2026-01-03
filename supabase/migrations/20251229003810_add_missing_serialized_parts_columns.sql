/*
  # Add missing columns to serialized_parts table

  1. New Columns
    - `po_id` (uuid, nullable) - Link to purchase order header for convenience querying
    - `warranty_start_date` (date, nullable) - Warranty coverage start date
    - `warranty_end_date` (date, nullable) - Warranty coverage end date
  
  2. Changes
    - Add foreign key constraint from `po_id` to `purchase_orders.id`
    - All columns are nullable to support existing data and manual part creation
  
  3. Important Notes
    - These columns support the PO receiving workflow for serialized parts
    - `po_id` provides direct link to PO header alongside existing `po_line_id`
    - Warranty fields track coverage period for serialized equipment
    - No data migration needed (no existing serialized_parts records)
*/

-- Add po_id column to link to purchase order header
ALTER TABLE serialized_parts
  ADD COLUMN IF NOT EXISTS po_id UUID NULL;

-- Add foreign key constraint for po_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'serialized_parts_po_id_fkey'
      AND table_name = 'serialized_parts'
  ) THEN
    ALTER TABLE serialized_parts
      ADD CONSTRAINT serialized_parts_po_id_fkey
      FOREIGN KEY (po_id)
      REFERENCES purchase_orders(id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- Add warranty tracking columns
ALTER TABLE serialized_parts
  ADD COLUMN IF NOT EXISTS warranty_start_date DATE NULL,
  ADD COLUMN IF NOT EXISTS warranty_end_date DATE NULL;

-- Add index on po_id for efficient queries
CREATE INDEX IF NOT EXISTS idx_serialized_parts_po_id 
  ON serialized_parts(po_id) 
  WHERE po_id IS NOT NULL;

-- Add index on warranty dates for warranty tracking queries
CREATE INDEX IF NOT EXISTS idx_serialized_parts_warranty 
  ON serialized_parts(warranty_end_date) 
  WHERE warranty_end_date IS NOT NULL 
    AND status IN ('in_stock', 'installed');
