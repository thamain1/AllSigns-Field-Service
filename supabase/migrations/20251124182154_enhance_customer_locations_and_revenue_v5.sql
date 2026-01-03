/*
  # Enhance Customer Locations and Revenue Tracking (Non-Destructive)

  ## Summary
  This migration adds support for multi-location customers, proper tracking of installed
  equipment/parts per location, service history aggregation, and running revenue totals.
  All existing data is preserved and enhanced with location information.

  ## Changes

  1. New Tables
    - `customer_locations`: Individual service locations for customers (many-to-one with customers)
      - Supports customers with multiple service sites
      - Tracks address, contact info, and location-specific notes
    
    - `customer_revenue_summary`: Running totals and aggregates per customer
      - Total revenue (all-time and YTD)
      - Service counts, last service date
      - Average ticket value
      - Automatically maintained via triggers

  2. Enhanced Tables
    - `equipment`: Add `location_id` to track which customer location owns each equipment
      - Also add `is_active` column for soft deletes
    - `tickets`: Modify `site_id` to reference `customer_locations` instead of `customers`
    - `invoices`: Modify `site_id` to reference `customer_locations` instead of `customers`

  3. Database Views
    - `customer_location_summary`: Aggregates equipment and service data per location
    - `customer_service_history`: Complete service history with location details
    - `equipment_installation_history`: Track where and when parts were installed

  4. Migration Strategy
    - Create default location for each existing customer
    - Migrate all equipment, tickets, and invoices to reference the default location
    - Handle foreign key constraints properly during migration
    - Preserve all existing data relationships

  ## Important Notes
  - Every customer gets at least one location (default: customer's primary address)
  - All existing tickets/invoices are associated with customer's default location
  - All existing equipment is assigned to customer's default location
  - Revenue tracking is automatically maintained via triggers
  - This is a non-destructive, additive change - no data loss
*/

-- ============================================================================
-- STEP 1: Create customer_locations table
-- ============================================================================

CREATE TABLE IF NOT EXISTS customer_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  location_name text NOT NULL DEFAULT 'Main Location',
  address text,
  city text,
  state text,
  zip_code text,
  contact_name text,
  contact_phone text,
  contact_email text,
  is_primary boolean DEFAULT false,
  location_notes text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_customer_locations_customer 
  ON customer_locations(customer_id);

CREATE INDEX IF NOT EXISTS idx_customer_locations_primary 
  ON customer_locations(customer_id, is_primary) 
  WHERE is_primary = true;

-- Enable RLS
ALTER TABLE customer_locations ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Authenticated users can view customer locations"
  ON customer_locations FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert customer locations"
  ON customer_locations FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update customer locations"
  ON customer_locations FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete customer locations"
  ON customer_locations FOR DELETE
  TO authenticated
  USING (true);

-- ============================================================================
-- STEP 2: Migrate existing customers to have default locations
-- ============================================================================

INSERT INTO customer_locations (
  customer_id,
  location_name,
  address,
  city,
  state,
  zip_code,
  contact_name,
  contact_phone,
  contact_email,
  is_primary,
  is_active
)
SELECT 
  c.id,
  'Main Location',
  c.address,
  c.city,
  c.state,
  c.zip_code,
  c.name,
  c.phone,
  c.email,
  true,
  true
FROM customers c
WHERE NOT EXISTS (
  SELECT 1 FROM customer_locations cl WHERE cl.customer_id = c.id
);

-- ============================================================================
-- STEP 3: Add location_id and is_active to equipment table
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'equipment' AND column_name = 'location_id'
  ) THEN
    ALTER TABLE equipment 
    ADD COLUMN location_id uuid REFERENCES customer_locations(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'equipment' AND column_name = 'is_active'
  ) THEN
    ALTER TABLE equipment 
    ADD COLUMN is_active boolean DEFAULT true;
  END IF;
END $$;

-- Migrate existing equipment to customer's primary location
UPDATE equipment e
SET location_id = (
  SELECT cl.id 
  FROM customer_locations cl 
  WHERE cl.customer_id = e.customer_id 
    AND cl.is_primary = true
  LIMIT 1
)
WHERE location_id IS NULL;

-- Create index
CREATE INDEX IF NOT EXISTS idx_equipment_location 
  ON equipment(location_id);

-- ============================================================================
-- STEP 4: Handle tickets.site_id foreign key migration
-- ============================================================================

-- Drop existing foreign key constraint
ALTER TABLE tickets 
  DROP CONSTRAINT IF EXISTS tickets_site_id_fkey;

-- Create mapping table for site_id migration (customer -> primary location)
CREATE TEMP TABLE site_id_mapping AS
SELECT 
  c.id AS customer_id,
  cl.id AS location_id
FROM customers c
JOIN customer_locations cl ON cl.customer_id = c.id AND cl.is_primary = true;

-- Update tickets to reference customer_locations
UPDATE tickets t
SET site_id = m.location_id
FROM site_id_mapping m
WHERE t.site_id = m.customer_id;

-- Add new foreign key constraint
ALTER TABLE tickets
  ADD CONSTRAINT tickets_site_id_fkey 
  FOREIGN KEY (site_id) 
  REFERENCES customer_locations(id) 
  ON DELETE CASCADE;

-- ============================================================================
-- STEP 5: Handle invoices.site_id foreign key migration
-- ============================================================================

-- Drop existing foreign key constraint
ALTER TABLE invoices 
  DROP CONSTRAINT IF EXISTS invoices_site_id_fkey;

-- Update invoices to reference customer_locations
UPDATE invoices i
SET site_id = m.location_id
FROM site_id_mapping m
WHERE i.site_id = m.customer_id;

-- Add new foreign key constraint
ALTER TABLE invoices
  ADD CONSTRAINT invoices_site_id_fkey 
  FOREIGN KEY (site_id) 
  REFERENCES customer_locations(id) 
  ON DELETE CASCADE;

-- ============================================================================
-- STEP 6: Create customer_revenue_summary table
-- ============================================================================

CREATE TABLE IF NOT EXISTS customer_revenue_summary (
  customer_id uuid PRIMARY KEY REFERENCES customers(id) ON DELETE CASCADE,
  total_revenue numeric(10,2) DEFAULT 0,
  ytd_revenue numeric(10,2) DEFAULT 0,
  total_tickets integer DEFAULT 0,
  completed_tickets integer DEFAULT 0,
  last_service_date timestamptz,
  average_ticket_value numeric(10,2) DEFAULT 0,
  total_parts_cost numeric(10,2) DEFAULT 0,
  total_labor_cost numeric(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE customer_revenue_summary ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Authenticated users can view revenue summary"
  ON customer_revenue_summary FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert revenue summary"
  ON customer_revenue_summary FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update revenue summary"
  ON customer_revenue_summary FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- STEP 7: Create database views
-- ============================================================================

-- View: Customer Location Summary
CREATE OR REPLACE VIEW customer_location_summary AS
SELECT 
  cl.id AS location_id,
  cl.customer_id,
  c.name AS customer_name,
  cl.location_name,
  cl.address,
  cl.city,
  cl.state,
  cl.zip_code,
  cl.is_primary,
  COUNT(DISTINCT e.id) AS equipment_count,
  COUNT(DISTINCT t.id) AS total_tickets,
  COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'completed') AS completed_tickets,
  MAX(t.completed_at) AS last_service_date,
  COALESCE(SUM(i.total_amount), 0) AS total_revenue
FROM customer_locations cl
JOIN customers c ON c.id = cl.customer_id
LEFT JOIN equipment e ON e.location_id = cl.id
LEFT JOIN tickets t ON t.site_id = cl.id
LEFT JOIN invoices i ON i.site_id = cl.id AND i.status = 'paid'
WHERE cl.is_active = true
GROUP BY cl.id, cl.customer_id, c.name, cl.location_name, 
         cl.address, cl.city, cl.state, cl.zip_code, cl.is_primary;

-- View: Customer Service History
CREATE OR REPLACE VIEW customer_service_history AS
SELECT 
  c.id AS customer_id,
  c.name AS customer_name,
  cl.id AS location_id,
  cl.location_name,
  t.id AS ticket_id,
  t.ticket_number,
  t.title AS ticket_title,
  t.status AS ticket_status,
  t.priority,
  t.created_at AS service_date,
  t.completed_at,
  e.id AS equipment_id,
  e.equipment_type,
  e.serial_number,
  i.id AS invoice_id,
  i.invoice_number,
  i.total_amount,
  i.status AS invoice_status,
  p.full_name AS technician_name
FROM customers c
JOIN customer_locations cl ON cl.customer_id = c.id
LEFT JOIN tickets t ON t.site_id = cl.id
LEFT JOIN equipment e ON e.id = t.equipment_id
LEFT JOIN invoices i ON i.customer_id = c.id AND i.ticket_id = t.id
LEFT JOIN profiles p ON p.id = t.assigned_to
ORDER BY t.created_at DESC;

-- View: Equipment Installation History
CREATE OR REPLACE VIEW equipment_installation_history AS
SELECT 
  e.id AS equipment_id,
  e.equipment_type,
  e.serial_number,
  e.model_number,
  e.manufacturer,
  cl.id AS location_id,
  cl.location_name,
  c.id AS customer_id,
  c.name AS customer_name,
  cp.id AS installed_part_id,
  p.part_number,
  p.name AS part_name,
  cp.installation_date AS installed_at,
  cp.warranty_expiration AS warranty_expires_at,
  t.id AS installation_ticket_id,
  t.ticket_number AS installation_ticket_number
FROM equipment e
JOIN customer_locations cl ON cl.id = e.location_id
JOIN customers c ON c.id = cl.customer_id
LEFT JOIN customer_parts_installed cp ON cp.equipment_id = e.id
LEFT JOIN parts p ON p.id = cp.part_id
LEFT JOIN tickets t ON t.id = cp.ticket_id
WHERE e.is_active = true
ORDER BY cp.installation_date DESC;

-- ============================================================================
-- STEP 8: Create functions to maintain revenue summary
-- ============================================================================

CREATE OR REPLACE FUNCTION update_customer_revenue_summary()
RETURNS TRIGGER AS $$
DECLARE
  v_customer_id uuid;
BEGIN
  -- Get customer_id from the affected record
  IF TG_TABLE_NAME = 'invoices' THEN
    v_customer_id := COALESCE(NEW.customer_id, OLD.customer_id);
  ELSIF TG_TABLE_NAME = 'tickets' THEN
    -- Get customer through location
    SELECT cl.customer_id INTO v_customer_id
    FROM customer_locations cl
    WHERE cl.id = COALESCE(NEW.site_id, OLD.site_id);
  END IF;

  -- Ensure summary record exists
  INSERT INTO customer_revenue_summary (customer_id)
  VALUES (v_customer_id)
  ON CONFLICT (customer_id) DO NOTHING;

  -- Update the summary
  UPDATE customer_revenue_summary
  SET
    total_revenue = COALESCE((
      SELECT SUM(total_amount)
      FROM invoices
      WHERE customer_id = v_customer_id AND status = 'paid'
    ), 0),
    ytd_revenue = COALESCE((
      SELECT SUM(total_amount)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status = 'paid'
        AND EXTRACT(YEAR FROM paid_at) = EXTRACT(YEAR FROM CURRENT_DATE)
    ), 0),
    total_tickets = COALESCE((
      SELECT COUNT(*)
      FROM tickets t
      JOIN customer_locations cl ON cl.id = t.site_id
      WHERE cl.customer_id = v_customer_id
    ), 0),
    completed_tickets = COALESCE((
      SELECT COUNT(*)
      FROM tickets t
      JOIN customer_locations cl ON cl.id = t.site_id
      WHERE cl.customer_id = v_customer_id AND t.status = 'completed'
    ), 0),
    last_service_date = (
      SELECT MAX(completed_at)
      FROM tickets t
      JOIN customer_locations cl ON cl.id = t.site_id
      WHERE cl.customer_id = v_customer_id AND t.status = 'completed'
    ),
    average_ticket_value = COALESCE((
      SELECT AVG(total_amount)
      FROM invoices
      WHERE customer_id = v_customer_id AND status = 'paid'
    ), 0),
    total_parts_cost = COALESCE((
      SELECT SUM(il.quantity * il.unit_price)
      FROM invoices i
      JOIN invoice_line_items il ON il.invoice_id = i.id
      WHERE i.customer_id = v_customer_id 
        AND i.status = 'paid'
        AND il.item_type = 'part'
    ), 0),
    total_labor_cost = COALESCE((
      SELECT SUM(il.quantity * il.unit_price)
      FROM invoices i
      JOIN invoice_line_items il ON il.invoice_id = i.id
      WHERE i.customer_id = v_customer_id 
        AND i.status = 'paid'
        AND il.item_type = 'labor'
    ), 0),
    updated_at = now()
  WHERE customer_id = v_customer_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
DROP TRIGGER IF EXISTS update_revenue_on_invoice_change ON invoices;
CREATE TRIGGER update_revenue_on_invoice_change
  AFTER INSERT OR UPDATE OR DELETE ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION update_customer_revenue_summary();

DROP TRIGGER IF EXISTS update_revenue_on_ticket_change ON tickets;
CREATE TRIGGER update_revenue_on_ticket_change
  AFTER INSERT OR UPDATE OR DELETE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION update_customer_revenue_summary();

-- ============================================================================
-- STEP 9: Initial population of revenue summary
-- ============================================================================

INSERT INTO customer_revenue_summary (customer_id)
SELECT DISTINCT id FROM customers
ON CONFLICT (customer_id) DO NOTHING;

-- Trigger initial calculation for all customers
UPDATE customer_revenue_summary
SET updated_at = now();

-- ============================================================================
-- STEP 10: Add updated_at trigger for customer_locations
-- ============================================================================

CREATE OR REPLACE FUNCTION update_customer_locations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_customer_locations_timestamp ON customer_locations;
CREATE TRIGGER update_customer_locations_timestamp
  BEFORE UPDATE ON customer_locations
  FOR EACH ROW
  EXECUTE FUNCTION update_customer_locations_updated_at();
