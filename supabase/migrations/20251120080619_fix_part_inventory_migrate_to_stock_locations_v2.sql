/*
  # Fix Part Inventory and Migrate to Stock Locations v2

  1. Changes to part_inventory table
    - Add `stock_location_id` column if not exists
    - Add `unit_cost` column if not exists
    - Migrate data from warehouse_location_id to stock_location_id
    - Consolidate duplicate records
    - Drop old warehouse_location_id column
    - Add new constraints and indexes

  2. Data Migration
    - Map existing warehouse_locations to stock_locations
    - Consolidate duplicate inventory records by summing quantities
    - Preserve all existing inventory data
*/

-- Step 1: Add new columns if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'part_inventory' AND column_name = 'stock_location_id'
  ) THEN
    ALTER TABLE part_inventory 
    ADD COLUMN stock_location_id uuid REFERENCES stock_locations(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'part_inventory' AND column_name = 'unit_cost'
  ) THEN
    ALTER TABLE part_inventory 
    ADD COLUMN unit_cost numeric(10,2);
  END IF;
END $$;

-- Step 2: Migrate data if stock_location_id is null
UPDATE part_inventory pi
SET stock_location_id = sl.id
FROM warehouse_locations wl
JOIN stock_locations sl ON sl.location_type = 'warehouse' AND sl.name = 'Main Warehouse'
WHERE pi.warehouse_location_id = wl.id 
  AND wl.location_type = 'main_warehouse'
  AND pi.stock_location_id IS NULL;

UPDATE part_inventory pi
SET stock_location_id = sl.id
FROM warehouse_locations wl
JOIN stock_locations sl ON sl.assigned_to_user_id = wl.technician_id AND sl.is_mobile = true
WHERE pi.warehouse_location_id = wl.id 
  AND wl.location_type = 'vehicle'
  AND wl.technician_id IS NOT NULL
  AND pi.stock_location_id IS NULL;

UPDATE part_inventory pi
SET stock_location_id = (
  SELECT id FROM stock_locations 
  WHERE location_type = 'warehouse' 
  ORDER BY name 
  LIMIT 1
)
WHERE pi.stock_location_id IS NULL;

-- Step 3: Create temp table to identify duplicates and consolidate
CREATE TEMP TABLE inventory_consolidation AS
SELECT 
  part_id,
  stock_location_id,
  SUM(quantity) as total_quantity,
  MAX(unit_cost) as consolidated_unit_cost,
  MIN(created_at) as earliest_created,
  (ARRAY_AGG(id ORDER BY created_at))[1] as keep_id
FROM part_inventory
WHERE stock_location_id IS NOT NULL
GROUP BY part_id, stock_location_id;

-- Step 4: Update the records we're keeping
UPDATE part_inventory pi
SET 
  quantity = ic.total_quantity,
  unit_cost = COALESCE(pi.unit_cost, ic.consolidated_unit_cost),
  created_at = ic.earliest_created
FROM inventory_consolidation ic
WHERE pi.id = ic.keep_id;

-- Step 5: Delete duplicates (keeping only the record we selected)
DELETE FROM part_inventory
WHERE id NOT IN (SELECT keep_id FROM inventory_consolidation);

-- Step 6: Make stock_location_id NOT NULL
ALTER TABLE part_inventory 
ALTER COLUMN stock_location_id SET NOT NULL;

-- Step 7: Drop old column and constraint
ALTER TABLE part_inventory 
DROP CONSTRAINT IF EXISTS part_inventory_part_id_warehouse_location_id_key;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'part_inventory' AND column_name = 'warehouse_location_id'
  ) THEN
    ALTER TABLE part_inventory DROP COLUMN warehouse_location_id;
  END IF;
END $$;

-- Step 8: Add new unique constraint
ALTER TABLE part_inventory 
DROP CONSTRAINT IF EXISTS part_inventory_part_id_stock_location_id_key;

ALTER TABLE part_inventory 
ADD CONSTRAINT part_inventory_part_id_stock_location_id_key 
UNIQUE(part_id, stock_location_id);

-- Step 9: Create indexes
DROP INDEX IF EXISTS idx_part_inventory_warehouse;
CREATE INDEX IF NOT EXISTS idx_part_inventory_stock_location 
ON part_inventory(stock_location_id);

-- Step 10: Ensure updated_at trigger exists
CREATE OR REPLACE FUNCTION update_part_inventory_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_part_inventory_updated_at ON part_inventory;

CREATE TRIGGER update_part_inventory_updated_at
  BEFORE UPDATE ON part_inventory
  FOR EACH ROW
  EXECUTE FUNCTION update_part_inventory_updated_at();
