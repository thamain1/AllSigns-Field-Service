/*
  # Unify Inventory System - Part 1: Synchronization and Views

  ## Summary
  This migration establishes `part_inventory` + `stock_locations` as the single source 
  of truth for inventory and creates mechanisms to keep the legacy `parts.quantity_on_hand` 
  field synchronized for backwards compatibility.

  ## Changes

  1. Database Views
    - `part_inventory_summary`: Aggregates inventory by part across all locations
    - `part_inventory_details`: Detailed view with location information

  2. Synchronization Function
    - `sync_part_total_quantity()`: Updates parts.quantity_on_hand based on part_inventory totals
    - Triggered automatically on part_inventory INSERT, UPDATE, DELETE

  3. Initial Data Sync
    - One-time sync of all existing parts.quantity_on_hand to match part_inventory totals

  4. Deprecation Note
    - `inventory_balances` table marked as deprecated (not used)
    - `warehouse_locations` table kept for reference but superseded by `stock_locations`

  ## Important Notes
  - `part_inventory` is now the canonical source for inventory quantities
  - `parts.quantity_on_hand` is maintained as a denormalized cache (updated via trigger)
  - All inventory operations MUST go through `part_inventory` table
  - Direct updates to `parts.quantity_on_hand` should be avoided
*/

-- Create view for inventory summary by part
CREATE OR REPLACE VIEW part_inventory_summary AS
SELECT 
  p.id AS part_id,
  p.part_number,
  p.name AS part_name,
  COALESCE(SUM(pi.quantity), 0)::integer AS total_quantity,
  COUNT(pi.id) AS location_count,
  ARRAY_AGG(
    DISTINCT sl.name ORDER BY sl.name
  ) FILTER (WHERE pi.quantity > 0) AS locations_with_stock
FROM parts p
LEFT JOIN part_inventory pi ON p.id = pi.part_id
LEFT JOIN stock_locations sl ON pi.stock_location_id = sl.id
GROUP BY p.id, p.part_number, p.name;

-- Create detailed inventory view with location information
CREATE OR REPLACE VIEW part_inventory_details AS
SELECT 
  p.id AS part_id,
  p.part_number,
  p.name AS part_name,
  p.category,
  p.manufacturer,
  pi.id AS inventory_id,
  pi.quantity,
  pi.unit_cost,
  sl.id AS location_id,
  sl.location_code,
  sl.name AS location_name,
  sl.location_type,
  sl.is_mobile,
  sl.assigned_to_user_id,
  sl.is_active AS location_active,
  pi.created_at,
  pi.updated_at
FROM parts p
LEFT JOIN part_inventory pi ON p.id = pi.part_id
LEFT JOIN stock_locations sl ON pi.stock_location_id = sl.id
WHERE sl.is_active = true OR sl.is_active IS NULL
ORDER BY p.name, sl.location_type, sl.name;

-- Create function to sync parts.quantity_on_hand with part_inventory total
CREATE OR REPLACE FUNCTION sync_part_total_quantity()
RETURNS TRIGGER AS $$
DECLARE
  affected_part_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    affected_part_id := OLD.part_id;
  ELSE
    affected_part_id := NEW.part_id;
  END IF;

  UPDATE parts
  SET 
    quantity_on_hand = COALESCE((
      SELECT SUM(quantity)::integer
      FROM part_inventory
      WHERE part_id = affected_part_id
    ), 0),
    updated_at = now()
  WHERE id = affected_part_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically sync totals
DROP TRIGGER IF EXISTS sync_part_quantity_on_inventory_change ON part_inventory;

CREATE TRIGGER sync_part_quantity_on_inventory_change
  AFTER INSERT OR UPDATE OR DELETE ON part_inventory
  FOR EACH ROW
  EXECUTE FUNCTION sync_part_total_quantity();

-- Initial sync: Update all parts.quantity_on_hand to match part_inventory totals
UPDATE parts p
SET 
  quantity_on_hand = COALESCE((
    SELECT SUM(pi.quantity)::integer
    FROM part_inventory pi
    WHERE pi.part_id = p.id
  ), 0),
  updated_at = now();

-- Add comment to parts.quantity_on_hand to indicate it's now computed
COMMENT ON COLUMN parts.quantity_on_hand IS 
  'Automatically computed total from part_inventory. Do not update directly - use part_inventory instead.';

-- Add comment to inventory_balances table to mark as deprecated
COMMENT ON TABLE inventory_balances IS 
  'DEPRECATED: Use part_inventory table instead. This table was created but never implemented.';
