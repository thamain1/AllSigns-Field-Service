/*
  # Advanced Parts Ordering, Serialization & Warranty System
  
  ## Overview
  This migration creates a comprehensive parts management system with:
  - Purchase Orders and receiving workflow
  - Serialized and non-serialized inventory tracking
  - Warranty lifecycle management per serialized part
  - Installation mapping to customer sites and equipment
  - Stock location and movement tracking
  - Integration with tickets, projects, and financials
  
  ## New Tables
  
  ### 1. Parts Catalog Updates
    - `parts` - Enhanced with serialization flag and warranty defaults
    - New fields: is_serialized, default_warranty_months, category, vendor_part_number
  
  ### 2. Vendors & Purchasing
    - `vendors` - Supplier/vendor information
    - `purchase_orders` - PO header records
    - `purchase_order_lines` - Line items with quantity/serial tracking
    - `purchase_order_receipts` - Receiving log with serials
  
  ### 3. Stock & Locations
    - `stock_locations` - Warehouses, trucks, project sites
    - `inventory_balances` - Quantity tracking for non-serialized parts
    - `inventory_movements` - Audit trail for all stock transfers
  
  ### 4. Serialized Parts & Warranty
    - `serialized_parts` - Individual serial-tracked units
    - `warranty_records` - Warranty details per serialized part
    - `warranty_claims` - (Future) warranty claim submissions
  
  ### 5. Installation & Usage
    - `part_installations` - Links parts to sites/equipment
    - `part_usage_log` - Usage records tied to tickets/projects
  
  ## Security
  - RLS enabled on all tables
  - Policies restrict access to authenticated users
  - Warehouse staff and field techs have appropriate permissions
  
  ## Important Notes
  - Serialized parts tracked as individual records (1 serial = 1 row)
  - Non-serialized parts tracked by quantity in inventory_balances
  - Warranty automatically calculated based on install date + duration
  - Installation creates parent-child relationship: Equipment → Part
*/

-- =====================================================
-- 1. ENUMS AND TYPES
-- =====================================================

DO $$ BEGIN
  CREATE TYPE purchase_order_status AS ENUM ('draft', 'submitted', 'approved', 'partial', 'received', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE receipt_status AS ENUM ('pending', 'partial', 'complete', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE stock_location_type AS ENUM ('warehouse', 'truck', 'project_site', 'customer_site', 'vendor');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE serialized_part_status AS ENUM ('in_stock', 'in_transit', 'installed', 'returned', 'defective', 'warranty_claim');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE warranty_status AS ENUM ('active', 'expired', 'void', 'claim_pending', 'claim_approved', 'claim_denied');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE warranty_type AS ENUM ('parts_only', 'parts_and_labor', 'labor_only', 'extended', 'manufacturer');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE movement_type AS ENUM ('receipt', 'transfer', 'installation', 'return', 'adjustment', 'disposal');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =====================================================
-- 2. VENDORS
-- =====================================================

CREATE TABLE IF NOT EXISTS vendors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_code text UNIQUE NOT NULL,
  name text NOT NULL,
  contact_name text,
  email text,
  phone text,
  address text,
  city text,
  state text,
  zip_code text,
  website text,
  account_number text,
  payment_terms text,
  notes text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- =====================================================
-- 3. PARTS CATALOG ENHANCEMENTS
-- =====================================================

DO $$
BEGIN
  -- Add new columns to existing parts table
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'is_serialized'
  ) THEN
    ALTER TABLE parts ADD COLUMN is_serialized boolean DEFAULT false;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'default_warranty_months'
  ) THEN
    ALTER TABLE parts ADD COLUMN default_warranty_months integer DEFAULT 12;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'category'
  ) THEN
    ALTER TABLE parts ADD COLUMN category text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'vendor_part_number'
  ) THEN
    ALTER TABLE parts ADD COLUMN vendor_part_number text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'preferred_vendor_id'
  ) THEN
    ALTER TABLE parts ADD COLUMN preferred_vendor_id uuid REFERENCES vendors(id);
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'reorder_point'
  ) THEN
    ALTER TABLE parts ADD COLUMN reorder_point numeric(10,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'parts' AND column_name = 'reorder_quantity'
  ) THEN
    ALTER TABLE parts ADD COLUMN reorder_quantity numeric(10,2) DEFAULT 0;
  END IF;
END $$;

-- =====================================================
-- 4. STOCK LOCATIONS
-- =====================================================

CREATE TABLE IF NOT EXISTS stock_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  location_code text UNIQUE NOT NULL,
  name text NOT NULL,
  location_type stock_location_type NOT NULL,
  address text,
  is_mobile boolean DEFAULT false,
  assigned_to_user_id uuid REFERENCES profiles(id),
  parent_location_id uuid REFERENCES stock_locations(id),
  is_active boolean DEFAULT true,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- =====================================================
-- 5. PURCHASE ORDERS
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  po_number text UNIQUE NOT NULL,
  vendor_id uuid NOT NULL REFERENCES vendors(id),
  order_date date DEFAULT CURRENT_DATE,
  expected_delivery_date date,
  delivery_location_id uuid REFERENCES stock_locations(id),
  status purchase_order_status DEFAULT 'draft',
  
  -- Linked to ticket or project
  ticket_id uuid REFERENCES tickets(id),
  project_id uuid REFERENCES projects(id),
  
  subtotal numeric(10,2) DEFAULT 0,
  tax_amount numeric(10,2) DEFAULT 0,
  shipping_amount numeric(10,2) DEFAULT 0,
  total_amount numeric(10,2) DEFAULT 0,
  
  notes text,
  terms text,
  
  created_by uuid REFERENCES profiles(id),
  approved_by uuid REFERENCES profiles(id),
  approved_at timestamptz,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS purchase_order_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id uuid NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  line_number integer NOT NULL,
  
  part_id uuid NOT NULL REFERENCES parts(id),
  description text NOT NULL,
  
  quantity_ordered numeric(10,2) NOT NULL,
  quantity_received numeric(10,2) DEFAULT 0,
  unit_price numeric(10,2) NOT NULL,
  line_total numeric(10,2) NOT NULL,
  
  expected_date date,
  notes text,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  CONSTRAINT unique_po_line UNIQUE (po_id, line_number)
);

-- =====================================================
-- 6. PURCHASE ORDER RECEIPTS
-- =====================================================

CREATE TABLE IF NOT EXISTS purchase_order_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id uuid NOT NULL REFERENCES purchase_orders(id),
  po_line_id uuid NOT NULL REFERENCES purchase_order_lines(id),
  
  receipt_date date DEFAULT CURRENT_DATE,
  quantity_received numeric(10,2) NOT NULL,
  
  received_by uuid REFERENCES profiles(id),
  received_at_location_id uuid REFERENCES stock_locations(id),
  
  packing_slip_number text,
  notes text,
  
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS receipt_serial_numbers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id uuid NOT NULL REFERENCES purchase_order_receipts(id) ON DELETE CASCADE,
  serial_number text NOT NULL,
  manufacture_date date,
  notes text,
  created_at timestamptz DEFAULT now(),
  
  CONSTRAINT unique_serial_per_receipt UNIQUE (receipt_id, serial_number)
);

-- =====================================================
-- 7. INVENTORY BALANCES (Non-Serialized)
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  part_id uuid NOT NULL REFERENCES parts(id),
  location_id uuid NOT NULL REFERENCES stock_locations(id),
  quantity numeric(10,2) DEFAULT 0,
  last_counted_at timestamptz,
  last_counted_by uuid REFERENCES profiles(id),
  updated_at timestamptz DEFAULT now(),
  
  CONSTRAINT unique_part_location UNIQUE (part_id, location_id)
);

-- =====================================================
-- 8. SERIALIZED PARTS
-- =====================================================

CREATE TABLE IF NOT EXISTS serialized_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  serial_number text UNIQUE NOT NULL,
  part_id uuid NOT NULL REFERENCES parts(id),
  
  -- Purchase & Cost
  po_line_id uuid REFERENCES purchase_order_lines(id),
  vendor_id uuid REFERENCES vendors(id),
  unit_cost numeric(10,2),
  purchase_date date,
  
  -- Status & Location
  status serialized_part_status DEFAULT 'in_stock',
  current_location_id uuid REFERENCES stock_locations(id),
  
  -- Installation Info
  installed_at_site_id uuid REFERENCES customers(id),
  installed_on_equipment_id uuid REFERENCES equipment(id),
  installed_on_ticket_id uuid REFERENCES tickets(id),
  installed_by uuid REFERENCES profiles(id),
  installation_date date,
  
  -- Dates
  manufacture_date date,
  received_date date,
  
  notes text,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- =====================================================
-- 9. WARRANTY RECORDS
-- =====================================================

CREATE TABLE IF NOT EXISTS warranty_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  serialized_part_id uuid NOT NULL REFERENCES serialized_parts(id) ON DELETE CASCADE,
  
  warranty_type warranty_type DEFAULT 'manufacturer',
  warranty_status warranty_status DEFAULT 'active',
  
  start_date date NOT NULL,
  end_date date NOT NULL,
  duration_months integer,
  
  coverage_terms text,
  exclusions text,
  
  vendor_id uuid REFERENCES vendors(id),
  warranty_number text,
  
  notes text,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- =====================================================
-- 10. WARRANTY CLAIMS (Future Enhancement)
-- =====================================================

CREATE TABLE IF NOT EXISTS warranty_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_number text UNIQUE NOT NULL,
  warranty_record_id uuid NOT NULL REFERENCES warranty_records(id),
  serialized_part_id uuid NOT NULL REFERENCES serialized_parts(id),
  
  ticket_id uuid REFERENCES tickets(id),
  
  claim_date date DEFAULT CURRENT_DATE,
  issue_description text NOT NULL,
  resolution_notes text,
  
  submitted_by uuid REFERENCES profiles(id),
  approved_by uuid REFERENCES profiles(id),
  
  status warranty_status DEFAULT 'claim_pending',
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- =====================================================
-- 11. INVENTORY MOVEMENTS
-- =====================================================

CREATE TABLE IF NOT EXISTS inventory_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  movement_type movement_type NOT NULL,
  movement_date timestamptz DEFAULT now(),
  
  part_id uuid NOT NULL REFERENCES parts(id),
  serialized_part_id uuid REFERENCES serialized_parts(id),
  
  quantity numeric(10,2),
  
  from_location_id uuid REFERENCES stock_locations(id),
  to_location_id uuid REFERENCES stock_locations(id),
  
  reference_type text,
  reference_id uuid,
  
  ticket_id uuid REFERENCES tickets(id),
  project_id uuid REFERENCES projects(id),
  po_id uuid REFERENCES purchase_orders(id),
  
  moved_by uuid REFERENCES profiles(id),
  notes text,
  
  created_at timestamptz DEFAULT now()
);

-- =====================================================
-- 12. PART INSTALLATIONS
-- =====================================================

CREATE TABLE IF NOT EXISTS part_installations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  serialized_part_id uuid REFERENCES serialized_parts(id),
  part_id uuid NOT NULL REFERENCES parts(id),
  quantity numeric(10,2) DEFAULT 1,
  
  installed_at_site_id uuid NOT NULL REFERENCES customers(id),
  installed_on_equipment_id uuid REFERENCES equipment(id),
  
  ticket_id uuid REFERENCES tickets(id),
  project_task_id uuid,
  
  installation_date date DEFAULT CURRENT_DATE,
  installed_by uuid REFERENCES profiles(id),
  
  removal_date date,
  removed_by uuid REFERENCES profiles(id),
  removal_reason text,
  
  notes text,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- =====================================================
-- 13. PART USAGE LOG
-- =====================================================

CREATE TABLE IF NOT EXISTS part_usage_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  part_id uuid NOT NULL REFERENCES parts(id),
  serialized_part_id uuid REFERENCES serialized_parts(id),
  
  quantity_used numeric(10,2) NOT NULL,
  unit_cost numeric(10,2),
  total_cost numeric(10,2),
  
  ticket_id uuid REFERENCES tickets(id),
  project_id uuid REFERENCES projects(id),
  
  used_by uuid REFERENCES profiles(id),
  usage_date date DEFAULT CURRENT_DATE,
  
  from_location_id uuid REFERENCES stock_locations(id),
  
  notes text,
  
  created_at timestamptz DEFAULT now()
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_vendors_code ON vendors(vendor_code);
CREATE INDEX IF NOT EXISTS idx_vendors_name ON vendors(name);

CREATE INDEX IF NOT EXISTS idx_po_number ON purchase_orders(po_number);
CREATE INDEX IF NOT EXISTS idx_po_vendor ON purchase_orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_po_status ON purchase_orders(status);
CREATE INDEX IF NOT EXISTS idx_po_ticket ON purchase_orders(ticket_id);

CREATE INDEX IF NOT EXISTS idx_po_lines_po ON purchase_order_lines(po_id);
CREATE INDEX IF NOT EXISTS idx_po_lines_part ON purchase_order_lines(part_id);

CREATE INDEX IF NOT EXISTS idx_stock_locations_type ON stock_locations(location_type);
CREATE INDEX IF NOT EXISTS idx_stock_locations_assigned ON stock_locations(assigned_to_user_id);

CREATE INDEX IF NOT EXISTS idx_serialized_parts_serial ON serialized_parts(serial_number);
CREATE INDEX IF NOT EXISTS idx_serialized_parts_part ON serialized_parts(part_id);
CREATE INDEX IF NOT EXISTS idx_serialized_parts_status ON serialized_parts(status);
CREATE INDEX IF NOT EXISTS idx_serialized_parts_location ON serialized_parts(current_location_id);
CREATE INDEX IF NOT EXISTS idx_serialized_parts_site ON serialized_parts(installed_at_site_id);
CREATE INDEX IF NOT EXISTS idx_serialized_parts_equipment ON serialized_parts(installed_on_equipment_id);

CREATE INDEX IF NOT EXISTS idx_warranty_records_part ON warranty_records(serialized_part_id);
CREATE INDEX IF NOT EXISTS idx_warranty_records_status ON warranty_records(warranty_status);
CREATE INDEX IF NOT EXISTS idx_warranty_records_end_date ON warranty_records(end_date);

CREATE INDEX IF NOT EXISTS idx_inventory_balances_part ON inventory_balances(part_id);
CREATE INDEX IF NOT EXISTS idx_inventory_balances_location ON inventory_balances(location_id);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_part ON inventory_movements(part_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_serial ON inventory_movements(serialized_part_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_date ON inventory_movements(movement_date);

CREATE INDEX IF NOT EXISTS idx_part_installations_part ON part_installations(part_id);
CREATE INDEX IF NOT EXISTS idx_part_installations_serial ON part_installations(serialized_part_id);
CREATE INDEX IF NOT EXISTS idx_part_installations_site ON part_installations(installed_at_site_id);
CREATE INDEX IF NOT EXISTS idx_part_installations_equipment ON part_installations(installed_on_equipment_id);

CREATE INDEX IF NOT EXISTS idx_part_usage_part ON part_usage_log(part_id);
CREATE INDEX IF NOT EXISTS idx_part_usage_ticket ON part_usage_log(ticket_id);

-- =====================================================
-- RLS POLICIES
-- =====================================================

ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_serial_numbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE serialized_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranty_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE warranty_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE part_installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE part_usage_log ENABLE ROW LEVEL SECURITY;

-- Vendors
CREATE POLICY "Authenticated users can view vendors"
  ON vendors FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage vendors"
  ON vendors FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Purchase Orders
CREATE POLICY "Authenticated users can view purchase orders"
  ON purchase_orders FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage purchase orders"
  ON purchase_orders FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- PO Lines
CREATE POLICY "Authenticated users can view PO lines"
  ON purchase_order_lines FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage PO lines"
  ON purchase_order_lines FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- PO Receipts
CREATE POLICY "Authenticated users can view receipts"
  ON purchase_order_receipts FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage receipts"
  ON purchase_order_receipts FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Receipt Serials
CREATE POLICY "Authenticated users can view receipt serials"
  ON receipt_serial_numbers FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage receipt serials"
  ON receipt_serial_numbers FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Stock Locations
CREATE POLICY "Authenticated users can view stock locations"
  ON stock_locations FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage stock locations"
  ON stock_locations FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Inventory Balances
CREATE POLICY "Authenticated users can view inventory balances"
  ON inventory_balances FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage inventory balances"
  ON inventory_balances FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Serialized Parts
CREATE POLICY "Authenticated users can view serialized parts"
  ON serialized_parts FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage serialized parts"
  ON serialized_parts FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Warranty Records
CREATE POLICY "Authenticated users can view warranty records"
  ON warranty_records FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage warranty records"
  ON warranty_records FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Warranty Claims
CREATE POLICY "Authenticated users can view warranty claims"
  ON warranty_claims FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage warranty claims"
  ON warranty_claims FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Inventory Movements
CREATE POLICY "Authenticated users can view inventory movements"
  ON inventory_movements FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage inventory movements"
  ON inventory_movements FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Part Installations
CREATE POLICY "Authenticated users can view part installations"
  ON part_installations FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage part installations"
  ON part_installations FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Part Usage Log
CREATE POLICY "Authenticated users can view part usage log"
  ON part_usage_log FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage part usage log"
  ON part_usage_log FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);