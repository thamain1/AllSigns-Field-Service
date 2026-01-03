/*
  # Create Warehouse Locations and Part Inventory Tracking

  1. New Tables
    - `warehouse_locations`
      - `id` (uuid, primary key)
      - `name` (text) - Name of the warehouse or vehicle
      - `location_type` (text) - 'main_warehouse', 'vehicle', or 'customer_site'
      - `vehicle_id` (text, nullable) - Vehicle identifier for vehicle warehouses
      - `technician_id` (uuid, nullable) - Foreign key to profiles for vehicle assignments
      - `address` (text, nullable) - Physical address
      - `is_active` (boolean) - Whether the location is currently active
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `part_inventory`
      - `id` (uuid, primary key)
      - `part_id` (uuid) - Foreign key to parts
      - `warehouse_location_id` (uuid) - Foreign key to warehouse_locations
      - `quantity` (integer) - Quantity at this location
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on both tables
    - Add policies for authenticated users to read and manage inventory

  3. Notes
    - Main warehouse is the central storage facility
    - Vehicles act as mobile warehouses assigned to technicians
    - Parts flow: Main Warehouse -> Vehicle -> Customer Site
    - The existing parts.quantity_on_hand will be migrated to represent total across all locations
*/

-- Create warehouse_locations table
CREATE TABLE IF NOT EXISTS warehouse_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  location_type text NOT NULL CHECK (location_type IN ('main_warehouse', 'vehicle', 'customer_site')),
  vehicle_id text,
  technician_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  address text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create part_inventory table
CREATE TABLE IF NOT EXISTS part_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  part_id uuid NOT NULL REFERENCES parts(id) ON DELETE CASCADE,
  warehouse_location_id uuid NOT NULL REFERENCES warehouse_locations(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(part_id, warehouse_location_id)
);

-- Enable RLS
ALTER TABLE warehouse_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE part_inventory ENABLE ROW LEVEL SECURITY;

-- Policies for warehouse_locations
CREATE POLICY "Authenticated users can view warehouse locations"
  ON warehouse_locations FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert warehouse locations"
  ON warehouse_locations FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update warehouse locations"
  ON warehouse_locations FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete warehouse locations"
  ON warehouse_locations FOR DELETE
  TO authenticated
  USING (true);

-- Policies for part_inventory
CREATE POLICY "Authenticated users can view part inventory"
  ON part_inventory FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert part inventory"
  ON part_inventory FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update part inventory"
  ON part_inventory FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete part inventory"
  ON part_inventory FOR DELETE
  TO authenticated
  USING (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_warehouse_locations_type ON warehouse_locations(location_type);
CREATE INDEX IF NOT EXISTS idx_warehouse_locations_technician ON warehouse_locations(technician_id);
CREATE INDEX IF NOT EXISTS idx_part_inventory_part ON part_inventory(part_id);
CREATE INDEX IF NOT EXISTS idx_part_inventory_warehouse ON part_inventory(warehouse_location_id);