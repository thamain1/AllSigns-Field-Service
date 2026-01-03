/*
  # Create Customer Parts Installed Tracking

  1. New Tables
    - `customer_parts_installed`
      - `id` (uuid, primary key)
      - `customer_id` (uuid) - Foreign key to customers
      - `part_id` (uuid) - Foreign key to parts
      - `equipment_id` (uuid, nullable) - Foreign key to equipment (if installed on specific equipment)
      - `ticket_id` (uuid, nullable) - Foreign key to tickets (the service ticket where it was installed)
      - `quantity` (integer) - Number of units installed
      - `installation_date` (date) - When the part was installed
      - `installed_by` (uuid, nullable) - Foreign key to profiles (technician who installed it)
      - `location_notes` (text, nullable) - Specific location notes (e.g., "North AC unit", "Main furnace")
      - `warranty_expiration` (date, nullable) - When the part warranty expires
      - `notes` (text, nullable) - Additional notes
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on customer_parts_installed
    - Add policies for authenticated users to read and manage installed parts

  3. Notes
    - Tracks parts that have been installed at customer locations
    - Links to tickets to show which service call installed the part
    - Links to equipment to show which specific unit the part is in
    - Includes warranty tracking for installed parts
    - Provides complete history of parts installed at each customer location
*/

CREATE TABLE IF NOT EXISTS customer_parts_installed (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  part_id uuid NOT NULL REFERENCES parts(id) ON DELETE RESTRICT,
  equipment_id uuid REFERENCES equipment(id) ON DELETE SET NULL,
  ticket_id uuid REFERENCES tickets(id) ON DELETE SET NULL,
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
  installation_date date NOT NULL DEFAULT CURRENT_DATE,
  installed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  location_notes text,
  warranty_expiration date,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE customer_parts_installed ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view installed parts"
  ON customer_parts_installed FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert installed parts"
  ON customer_parts_installed FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update installed parts"
  ON customer_parts_installed FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete installed parts"
  ON customer_parts_installed FOR DELETE
  TO authenticated
  USING (true);

CREATE INDEX IF NOT EXISTS idx_customer_parts_customer ON customer_parts_installed(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_parts_part ON customer_parts_installed(part_id);
CREATE INDEX IF NOT EXISTS idx_customer_parts_equipment ON customer_parts_installed(equipment_id);
CREATE INDEX IF NOT EXISTS idx_customer_parts_ticket ON customer_parts_installed(ticket_id);
CREATE INDEX IF NOT EXISTS idx_customer_parts_installation_date ON customer_parts_installed(installation_date);