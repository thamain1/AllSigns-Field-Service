/*
  # Dunaway Heating and Cooling - Initial Database Schema

  ## Overview
  This migration creates the complete database structure for a field service management application
  for HVAC technicians, dispatchers, and administrators.

  ## 1. New Tables

  ### Authentication & Users
    - `profiles` - Extended user profile data linked to auth.users
      - `id` (uuid, references auth.users)
      - `email` (text)
      - `full_name` (text)
      - `role` (enum: admin, dispatcher, technician)
      - `phone` (text)
      - `avatar_url` (text)
      - `is_active` (boolean)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Customers
    - `customers` - Customer information
      - `id` (uuid, primary key)
      - `name` (text)
      - `email` (text)
      - `phone` (text)
      - `address` (text)
      - `city` (text)
      - `state` (text)
      - `zip_code` (text)
      - `notes` (text)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Parts Tracking
    - `parts` - Parts inventory
      - `id` (uuid, primary key)
      - `part_number` (text, unique)
      - `name` (text)
      - `description` (text)
      - `manufacturer` (text)
      - `category` (text)
      - `quantity_on_hand` (integer)
      - `unit_price` (decimal)
      - `location` (text)
      - `reorder_level` (integer)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Equipment Tracking
    - `equipment` - HVAC equipment tracking
      - `id` (uuid, primary key)
      - `customer_id` (uuid, references customers)
      - `serial_number` (text, unique)
      - `model_number` (text)
      - `manufacturer` (text)
      - `equipment_type` (text)
      - `installation_date` (date)
      - `warranty_expiration` (date)
      - `warranty_status` (text)
      - `location` (text)
      - `notes` (text)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Service Tickets
    - `tickets` - Service tickets/work orders
      - `id` (uuid, primary key)
      - `ticket_number` (text, unique)
      - `customer_id` (uuid, references customers)
      - `equipment_id` (uuid, references equipment, optional)
      - `assigned_to` (uuid, references profiles, optional)
      - `status` (enum: open, scheduled, in_progress, completed, cancelled)
      - `priority` (enum: low, normal, high, urgent)
      - `title` (text)
      - `description` (text)
      - `service_type` (text)
      - `scheduled_date` (timestamptz)
      - `completed_date` (timestamptz)
      - `created_by` (uuid, references profiles)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Ticket Notes & Diagnostics
    - `ticket_notes` - Notes and updates on tickets
      - `id` (uuid, primary key)
      - `ticket_id` (uuid, references tickets)
      - `created_by` (uuid, references profiles)
      - `note_type` (enum: general, diagnostic, customer, internal)
      - `content` (text)
      - `created_at` (timestamptz)

  ### Ticket Photos
    - `ticket_photos` - Photo attachments for tickets
      - `id` (uuid, primary key)
      - `ticket_id` (uuid, references tickets)
      - `uploaded_by` (uuid, references profiles)
      - `photo_url` (text)
      - `caption` (text)
      - `created_at` (timestamptz)

  ### Parts Usage
    - `parts_usage` - Parts used on tickets
      - `id` (uuid, primary key)
      - `ticket_id` (uuid, references tickets)
      - `part_id` (uuid, references parts)
      - `quantity_used` (integer)
      - `recorded_by` (uuid, references profiles)
      - `created_at` (timestamptz)

  ### Technician Locations
    - `technician_locations` - GPS tracking for technicians
      - `id` (uuid, primary key)
      - `technician_id` (uuid, references profiles)
      - `latitude` (decimal)
      - `longitude` (decimal)
      - `accuracy` (decimal)
      - `timestamp` (timestamptz)

  ### Activity Log
    - `activity_log` - Audit trail for all actions
      - `id` (uuid, primary key)
      - `user_id` (uuid, references profiles)
      - `action` (text)
      - `entity_type` (text)
      - `entity_id` (uuid)
      - `details` (jsonb)
      - `created_at` (timestamptz)

  ## 2. Security
  
  All tables have Row Level Security (RLS) enabled with appropriate policies for:
  - Admins: Full access to all data
  - Dispatchers: Full access to tickets, parts, equipment, customers
  - Technicians: Read access to assigned tickets and related data, update capabilities for their work

  ## 3. Indexes
  
  Indexes added for:
  - Foreign key relationships
  - Frequently queried fields (ticket_number, serial_number, part_number)
  - Status and priority fields
  - Timestamp fields for sorting

  ## 4. Important Notes
  
  - All timestamps use `timestamptz` for proper timezone handling
  - UUIDs used for all primary keys for security and scalability
  - Enums defined for status fields to ensure data consistency
  - All tables include created_at and most include updated_at timestamps
  - Cascading deletes configured where appropriate to maintain referential integrity
*/

-- Create custom types/enums
CREATE TYPE user_role AS ENUM ('admin', 'dispatcher', 'technician');
CREATE TYPE ticket_status AS ENUM ('open', 'scheduled', 'in_progress', 'completed', 'cancelled');
CREATE TYPE ticket_priority AS ENUM ('low', 'normal', 'high', 'urgent');
CREATE TYPE note_type AS ENUM ('general', 'diagnostic', 'customer', 'internal');

-- Profiles table (extends auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  full_name text NOT NULL,
  role user_role NOT NULL DEFAULT 'technician',
  phone text,
  avatar_url text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text,
  phone text,
  address text,
  city text,
  state text,
  zip_code text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Parts table
CREATE TABLE IF NOT EXISTS parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  part_number text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  manufacturer text,
  category text,
  quantity_on_hand integer DEFAULT 0,
  unit_price decimal(10,2) DEFAULT 0,
  location text,
  reorder_level integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Equipment table
CREATE TABLE IF NOT EXISTS equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid REFERENCES customers(id) ON DELETE CASCADE,
  serial_number text UNIQUE NOT NULL,
  model_number text NOT NULL,
  manufacturer text NOT NULL,
  equipment_type text NOT NULL,
  installation_date date,
  warranty_expiration date,
  warranty_status text,
  location text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tickets table
CREATE TABLE IF NOT EXISTS tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number text UNIQUE NOT NULL,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  equipment_id uuid REFERENCES equipment(id) ON DELETE SET NULL,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  status ticket_status DEFAULT 'open',
  priority ticket_priority DEFAULT 'normal',
  title text NOT NULL,
  description text,
  service_type text,
  scheduled_date timestamptz,
  completed_date timestamptz,
  created_by uuid NOT NULL REFERENCES profiles(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Ticket notes table
CREATE TABLE IF NOT EXISTS ticket_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES profiles(id),
  note_type note_type DEFAULT 'general',
  content text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Ticket photos table
CREATE TABLE IF NOT EXISTS ticket_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  uploaded_by uuid NOT NULL REFERENCES profiles(id),
  photo_url text NOT NULL,
  caption text,
  created_at timestamptz DEFAULT now()
);

-- Parts usage table
CREATE TABLE IF NOT EXISTS parts_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  part_id uuid NOT NULL REFERENCES parts(id),
  quantity_used integer NOT NULL DEFAULT 1,
  recorded_by uuid NOT NULL REFERENCES profiles(id),
  created_at timestamptz DEFAULT now()
);

-- Technician locations table
CREATE TABLE IF NOT EXISTS technician_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  technician_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  latitude decimal(10,8) NOT NULL,
  longitude decimal(11,8) NOT NULL,
  accuracy decimal(10,2),
  timestamp timestamptz DEFAULT now()
);

-- Activity log table
CREATE TABLE IF NOT EXISTS activity_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  details jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_equipment_customer_id ON equipment(customer_id);
CREATE INDEX IF NOT EXISTS idx_equipment_serial_number ON equipment(serial_number);
CREATE INDEX IF NOT EXISTS idx_tickets_customer_id ON tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_priority ON tickets(priority);
CREATE INDEX IF NOT EXISTS idx_tickets_scheduled_date ON tickets(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_ticket_notes_ticket_id ON ticket_notes(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_photos_ticket_id ON ticket_photos(ticket_id);
CREATE INDEX IF NOT EXISTS idx_parts_usage_ticket_id ON parts_usage(ticket_id);
CREATE INDEX IF NOT EXISTS idx_parts_usage_part_id ON parts_usage(part_id);
CREATE INDEX IF NOT EXISTS idx_technician_locations_technician_id ON technician_locations(technician_id);
CREATE INDEX IF NOT EXISTS idx_technician_locations_timestamp ON technician_locations(timestamp);
CREATE INDEX IF NOT EXISTS idx_activity_log_user_id ON activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_entity_type ON activity_log(entity_type);
CREATE INDEX IF NOT EXISTS idx_activity_log_created_at ON activity_log(created_at);

-- Enable Row Level Security on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE parts_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE technician_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Admins can manage all profiles"
  ON profiles FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Customers policies
CREATE POLICY "Authenticated users can view customers"
  ON customers FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins and dispatchers can manage customers"
  ON customers FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
    )
  );

-- Parts policies
CREATE POLICY "Authenticated users can view parts"
  ON parts FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins and dispatchers can manage parts"
  ON parts FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
    )
  );

-- Equipment policies
CREATE POLICY "Authenticated users can view equipment"
  ON equipment FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins and dispatchers can manage equipment"
  ON equipment FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
    )
  );

-- Tickets policies
CREATE POLICY "Users can view tickets they're involved with"
  ON tickets FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND (
        role IN ('admin', 'dispatcher') OR
        (role = 'technician' AND tickets.assigned_to = auth.uid())
      )
    )
  );

CREATE POLICY "Admins and dispatchers can create tickets"
  ON tickets FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Admins and dispatchers can update any ticket"
  ON tickets FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Technicians can update assigned tickets"
  ON tickets FOR UPDATE
  TO authenticated
  USING (
    assigned_to = auth.uid() AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'technician'
    )
  )
  WITH CHECK (
    assigned_to = auth.uid()
  );

CREATE POLICY "Admins can delete tickets"
  ON tickets FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Ticket notes policies
CREATE POLICY "Users can view notes for accessible tickets"
  ON ticket_notes FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM tickets
      JOIN profiles ON profiles.id = auth.uid()
      WHERE tickets.id = ticket_notes.ticket_id AND (
        profiles.role IN ('admin', 'dispatcher') OR
        (profiles.role = 'technician' AND tickets.assigned_to = auth.uid())
      )
    )
  );

CREATE POLICY "Users can create notes on accessible tickets"
  ON ticket_notes FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM tickets
      JOIN profiles ON profiles.id = auth.uid()
      WHERE tickets.id = ticket_notes.ticket_id AND (
        profiles.role IN ('admin', 'dispatcher') OR
        (profiles.role = 'technician' AND tickets.assigned_to = auth.uid())
      )
    )
  );

-- Ticket photos policies
CREATE POLICY "Users can view photos for accessible tickets"
  ON ticket_photos FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM tickets
      JOIN profiles ON profiles.id = auth.uid()
      WHERE tickets.id = ticket_photos.ticket_id AND (
        profiles.role IN ('admin', 'dispatcher') OR
        (profiles.role = 'technician' AND tickets.assigned_to = auth.uid())
      )
    )
  );

CREATE POLICY "Users can upload photos to accessible tickets"
  ON ticket_photos FOR INSERT
  TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM tickets
      JOIN profiles ON profiles.id = auth.uid()
      WHERE tickets.id = ticket_photos.ticket_id AND (
        profiles.role IN ('admin', 'dispatcher') OR
        (profiles.role = 'technician' AND tickets.assigned_to = auth.uid())
      )
    )
  );

-- Parts usage policies
CREATE POLICY "Users can view parts usage for accessible tickets"
  ON parts_usage FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM tickets
      JOIN profiles ON profiles.id = auth.uid()
      WHERE tickets.id = parts_usage.ticket_id AND (
        profiles.role IN ('admin', 'dispatcher') OR
        (profiles.role = 'technician' AND tickets.assigned_to = auth.uid())
      )
    )
  );

CREATE POLICY "Users can record parts usage on accessible tickets"
  ON parts_usage FOR INSERT
  TO authenticated
  WITH CHECK (
    recorded_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM tickets
      JOIN profiles ON profiles.id = auth.uid()
      WHERE tickets.id = parts_usage.ticket_id AND (
        profiles.role IN ('admin', 'dispatcher') OR
        (profiles.role = 'technician' AND tickets.assigned_to = auth.uid())
      )
    )
  );

-- Technician locations policies
CREATE POLICY "Admins and dispatchers can view all technician locations"
  ON technician_locations FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Technicians can view own location history"
  ON technician_locations FOR SELECT
  TO authenticated
  USING (technician_id = auth.uid());

CREATE POLICY "Technicians can insert own location"
  ON technician_locations FOR INSERT
  TO authenticated
  WITH CHECK (technician_id = auth.uid());

-- Activity log policies
CREATE POLICY "Admins can view all activity logs"
  ON activity_log FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Users can view own activity logs"
  ON activity_log FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "All authenticated users can insert activity logs"
  ON activity_log FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_parts_updated_at BEFORE UPDATE ON parts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_equipment_updated_at BEFORE UPDATE ON equipment
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tickets_updated_at BEFORE UPDATE ON tickets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();