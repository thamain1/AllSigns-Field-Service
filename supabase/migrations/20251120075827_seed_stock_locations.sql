/*
  # Seed Stock Locations

  1. Purpose
    - Add default stock locations to enable parts receiving functionality
    - Includes main warehouse and example truck locations
    
  2. Stock Locations Created
    - Main Warehouse (warehouse type)
    - Service Truck 1 (truck type, mobile)
    - Service Truck 2 (truck type, mobile)
    
  3. Notes
    - All locations are active by default
    - Truck locations are marked as mobile
    - Location codes follow a simple naming convention
*/

-- Insert default stock locations
INSERT INTO stock_locations (location_code, name, location_type, is_mobile, is_active)
VALUES
  ('WH-MAIN', 'Main Warehouse', 'warehouse', false, true),
  ('TRUCK-001', 'Service Truck 1', 'truck', true, true),
  ('TRUCK-002', 'Service Truck 2', 'truck', true, true)
ON CONFLICT (location_code) DO NOTHING;
