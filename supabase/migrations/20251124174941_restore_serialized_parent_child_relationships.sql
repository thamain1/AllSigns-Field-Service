/*
  # Restore Serialized Parent-Child Relationships & Location Views

  ## Summary
  This migration creates database views and helper functions to properly display:
  1. Parent-child relationships between equipment and installed serialized parts
  2. Warranty information for serialized parts
  3. Proper location filtering (installed vs. in-stock vs. on-vehicles)

  ## Changes

  1. Views Created
    - `equipment_with_installed_parts`: Shows equipment with all child serialized parts
    - `serialized_parts_available_stock`: Shows only parts available in stock (not installed)
    - `serialized_parts_installed`: Shows only installed parts with full context
    - `vehicle_inventory_with_serials`: Shows vehicle inventory including serialized parts

  2. Helper Functions
    - `get_equipment_child_parts(equipment_id)`: Returns all parts installed on equipment
    - `get_serialized_part_location_status(part_id)`: Returns current location and status

  ## Important Notes
  - No existing data is modified
  - All existing fields preserved
  - Views provide read-only access with proper joins
  - Separates "in stock" from "installed" serialized parts
  - Vehicle inventories now correctly show only available (not installed) parts
*/

-- =====================================================
-- VIEW: Equipment with Installed Serialized Parts
-- =====================================================

CREATE OR REPLACE VIEW equipment_with_installed_parts AS
SELECT 
  e.id AS equipment_id,
  e.serial_number AS equipment_serial,
  e.model_number,
  e.manufacturer,
  e.equipment_type,
  e.customer_id,
  c.name AS customer_name,
  e.installation_date AS equipment_installation_date,
  e.warranty_expiration AS equipment_warranty_expiration,
  e.location AS equipment_location,
  
  -- Child parts information
  sp.id AS part_id,
  sp.serial_number AS part_serial_number,
  sp.status AS part_status,
  sp.installation_date AS part_installation_date,
  sp.installed_by,
  sp.installed_on_ticket_id,
  sp.unit_cost AS part_cost,
  
  -- Part details
  p.part_number,
  p.name AS part_name,
  p.manufacturer AS part_manufacturer,
  p.category AS part_category,
  
  -- Warranty information
  wr.id AS warranty_id,
  wr.warranty_type,
  wr.warranty_status,
  wr.start_date AS warranty_start,
  wr.end_date AS warranty_end,
  wr.duration_months AS warranty_duration,
  
  -- Calculated fields
  CASE 
    WHEN wr.end_date IS NULL THEN 'Unknown'
    WHEN wr.end_date < CURRENT_DATE THEN 'Expired'
    WHEN wr.end_date < (CURRENT_DATE + INTERVAL '90 days') THEN 'Expiring Soon'
    ELSE 'Active'
  END AS warranty_status_computed,
  
  CASE 
    WHEN wr.end_date IS NOT NULL AND wr.end_date >= CURRENT_DATE 
    THEN wr.end_date - CURRENT_DATE
    ELSE 0
  END AS warranty_days_remaining

FROM equipment e
LEFT JOIN customers c ON e.customer_id = c.id
LEFT JOIN serialized_parts sp ON sp.installed_on_equipment_id = e.id AND sp.status = 'installed'
LEFT JOIN parts p ON sp.part_id = p.id
LEFT JOIN warranty_records wr ON wr.serialized_part_id = sp.id
ORDER BY e.serial_number, p.name;

-- =====================================================
-- VIEW: Serialized Parts Available in Stock
-- =====================================================

CREATE OR REPLACE VIEW serialized_parts_available_stock AS
SELECT 
  sp.id,
  sp.serial_number,
  sp.part_id,
  sp.status,
  sp.current_location_id,
  sp.po_line_id,
  sp.vendor_id,
  sp.unit_cost,
  sp.purchase_date,
  sp.received_date,
  sp.manufacture_date,
  sp.notes,
  
  -- Part information
  p.part_number,
  p.name AS part_name,
  p.manufacturer AS part_manufacturer,
  p.category,
  p.unit_price,
  
  -- Location information
  sl.location_code,
  sl.name AS location_name,
  sl.location_type,
  sl.is_mobile,
  sl.assigned_to_user_id,
  
  -- Technician for mobile locations
  prof.full_name AS assigned_technician
  
FROM serialized_parts sp
JOIN parts p ON sp.part_id = p.id
LEFT JOIN stock_locations sl ON sp.current_location_id = sl.id
LEFT JOIN profiles prof ON sl.assigned_to_user_id = prof.id OR sl.technician_id = prof.id

-- Only show parts that are NOT installed
WHERE sp.status IN ('in_stock', 'in_transit', 'returned', 'defective')
  AND sp.installed_on_equipment_id IS NULL
  AND sp.installed_at_site_id IS NULL
  
ORDER BY sl.name, p.name, sp.serial_number;

-- =====================================================
-- VIEW: Serialized Parts Installed
-- =====================================================

CREATE OR REPLACE VIEW serialized_parts_installed AS
SELECT 
  sp.id,
  sp.serial_number,
  sp.part_id,
  sp.status,
  sp.installation_date,
  sp.installed_by,
  sp.installed_on_ticket_id,
  sp.installed_at_site_id,
  sp.installed_on_equipment_id,
  sp.unit_cost,
  
  -- Part information
  p.part_number,
  p.name AS part_name,
  p.manufacturer AS part_manufacturer,
  p.category,
  
  -- Equipment (parent) information
  e.serial_number AS equipment_serial,
  e.model_number AS equipment_model,
  e.manufacturer AS equipment_manufacturer,
  e.equipment_type,
  
  -- Site information
  c.name AS customer_name,
  c.address AS site_address,
  c.city,
  c.state,
  c.zip_code,
  
  -- Installation ticket
  t.ticket_number,
  t.title AS ticket_title,
  
  -- Installer
  prof.full_name AS installed_by_name,
  
  -- Warranty information
  wr.warranty_type,
  wr.warranty_status,
  wr.start_date AS warranty_start,
  wr.end_date AS warranty_end,
  
  CASE 
    WHEN wr.end_date IS NULL THEN 'Unknown'
    WHEN wr.end_date < CURRENT_DATE THEN 'Expired'
    WHEN wr.end_date < (CURRENT_DATE + INTERVAL '90 days') THEN 'Expiring Soon'
    ELSE 'Active'
  END AS warranty_status_computed

FROM serialized_parts sp
JOIN parts p ON sp.part_id = p.id
LEFT JOIN equipment e ON sp.installed_on_equipment_id = e.id
LEFT JOIN customers c ON sp.installed_at_site_id = c.id
LEFT JOIN tickets t ON sp.installed_on_ticket_id = t.id
LEFT JOIN profiles prof ON sp.installed_by = prof.id
LEFT JOIN warranty_records wr ON wr.serialized_part_id = sp.id

WHERE sp.status = 'installed'
  OR sp.installed_on_equipment_id IS NOT NULL
  OR sp.installed_at_site_id IS NOT NULL
  
ORDER BY c.name, e.serial_number, p.name;

-- =====================================================
-- VIEW: Vehicle Inventory with Serialized Parts
-- =====================================================

CREATE OR REPLACE VIEW vehicle_inventory_with_serials AS
SELECT 
  sl.id AS location_id,
  sl.location_code,
  sl.name AS vehicle_name,
  sl.assigned_to_user_id,
  sl.technician_id,
  prof.full_name AS technician_name,
  
  -- Non-serialized inventory
  pi.part_id,
  pi.quantity AS non_serialized_quantity,
  pi.unit_cost,
  
  -- Part information
  p.part_number,
  p.name AS part_name,
  p.manufacturer,
  p.category,
  p.is_serialized,
  
  -- Serialized parts at this location (available only)
  (
    SELECT json_agg(
      json_build_object(
        'id', sp.id,
        'serial_number', sp.serial_number,
        'status', sp.status,
        'unit_cost', sp.unit_cost
      )
    )
    FROM serialized_parts sp
    WHERE sp.current_location_id = sl.id
      AND sp.part_id = p.id
      AND sp.status IN ('in_stock', 'in_transit')
      AND sp.installed_on_equipment_id IS NULL
  ) AS serialized_items

FROM stock_locations sl
LEFT JOIN part_inventory pi ON pi.stock_location_id = sl.id
LEFT JOIN parts p ON pi.part_id = p.id
LEFT JOIN profiles prof ON sl.assigned_to_user_id = prof.id OR sl.technician_id = prof.id

WHERE sl.location_type = 'truck' 
  AND sl.is_mobile = true
  AND sl.is_active = true
  
ORDER BY prof.full_name, p.name;

-- =====================================================
-- FUNCTION: Get Equipment Child Parts
-- =====================================================

CREATE OR REPLACE FUNCTION get_equipment_child_parts(equipment_uuid uuid)
RETURNS TABLE (
  part_id uuid,
  serial_number text,
  part_name text,
  part_number text,
  status text,
  installation_date date,
  warranty_status text,
  warranty_end date
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sp.id,
    sp.serial_number,
    p.name,
    p.part_number,
    sp.status::text,
    sp.installation_date,
    CASE 
      WHEN wr.end_date IS NULL THEN 'Unknown'
      WHEN wr.end_date < CURRENT_DATE THEN 'Expired'
      WHEN wr.end_date < (CURRENT_DATE + INTERVAL '90 days') THEN 'Expiring Soon'
      ELSE 'Active'
    END,
    wr.end_date
  FROM serialized_parts sp
  JOIN parts p ON sp.part_id = p.id
  LEFT JOIN warranty_records wr ON wr.serialized_part_id = sp.id
  WHERE sp.installed_on_equipment_id = equipment_uuid
    AND sp.status = 'installed'
  ORDER BY p.name, sp.serial_number;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION: Get Serialized Part Location Status
-- =====================================================

CREATE OR REPLACE FUNCTION get_serialized_part_location_status(part_uuid uuid)
RETURNS TABLE (
  location_type text,
  location_name text,
  is_installed boolean,
  installed_at text,
  parent_equipment text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    CASE 
      WHEN sp.status = 'installed' THEN 'installed'
      WHEN sl.location_type IS NOT NULL THEN sl.location_type::text
      ELSE 'unknown'
    END,
    COALESCE(
      CASE 
        WHEN sp.status = 'installed' THEN c.name
        ELSE sl.name
      END,
      'Unknown'
    ),
    (sp.status = 'installed' OR sp.installed_on_equipment_id IS NOT NULL),
    COALESCE(c.name, 'N/A'),
    COALESCE(e.serial_number || ' - ' || e.model_number, 'N/A')
  FROM serialized_parts sp
  LEFT JOIN stock_locations sl ON sp.current_location_id = sl.id
  LEFT JOIN customers c ON sp.installed_at_site_id = c.id
  LEFT JOIN equipment e ON sp.installed_on_equipment_id = e.id
  WHERE sp.id = part_uuid;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Grant permissions
-- =====================================================

GRANT SELECT ON equipment_with_installed_parts TO authenticated;
GRANT SELECT ON serialized_parts_available_stock TO authenticated;
GRANT SELECT ON serialized_parts_installed TO authenticated;
GRANT SELECT ON vehicle_inventory_with_serials TO authenticated;
GRANT EXECUTE ON FUNCTION get_equipment_child_parts TO authenticated;
GRANT EXECUTE ON FUNCTION get_serialized_part_location_status TO authenticated;
