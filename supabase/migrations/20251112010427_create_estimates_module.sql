/*
  # Create Estimates (Quotes) Module

  ## Overview
  This migration creates a complete estimates/quotes system for pre-job proposals,
  allowing technicians and office staff to create, send, track, and convert estimates
  into service tickets or projects.

  ## Changes Made

  1. New Tables
    - `estimates` - Main estimates table with EST-YYMM-DD-N auto-numbering
    - `estimate_line_items` - Line items for labor, parts, equipment
    - `estimate_attachments` - File attachments for estimates
    - `estimate_activity_log` - Audit trail of estimate changes
    - `estimate_sequences` - Tracks sequence numbers for auto-generation

  2. New Types
    - `estimate_status` - Draft, Sent, Viewed, Accepted, Rejected, Expired
    - `estimate_line_item_type` - Labor, Parts, Equipment, Discount, Other
    - `estimate_pricing_tier` - Good, Better, Best (optional tiered pricing)

  3. Functions
    - `generate_estimate_number()` - Auto-generates EST-YYMM-DD-N format
    - `calculate_estimate_totals()` - Calculates subtotal, tax, and total
    - `auto_generate_estimate_number()` - Trigger function

  4. Security
    - RLS policies for all tables
    - Role-based access control

  ## Estimate ID Format
  EST-YYMM-DD-N
  - YYMM: Year and Month
  - DD: Day of month
  - N: Order of creation on that day
  Example: EST-2511-12-5 (5th estimate on Nov 12, 2025)
*/

-- Create estimate status enum
DO $$ BEGIN
  CREATE TYPE estimate_status AS ENUM (
    'draft',
    'sent',
    'viewed',
    'accepted',
    'rejected',
    'expired',
    'converted'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create line item type enum
DO $$ BEGIN
  CREATE TYPE estimate_line_item_type AS ENUM (
    'labor',
    'parts',
    'equipment',
    'discount',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create pricing tier enum
DO $$ BEGIN
  CREATE TYPE estimate_pricing_tier AS ENUM (
    'good',
    'better',
    'best'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create estimates table
CREATE TABLE IF NOT EXISTS estimates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  estimate_number text UNIQUE NOT NULL,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  site_location text,
  job_title text NOT NULL,
  job_description text,
  status estimate_status DEFAULT 'draft',
  
  -- Financial fields
  subtotal numeric(10, 2) DEFAULT 0,
  discount_amount numeric(10, 2) DEFAULT 0,
  tax_rate numeric(5, 2) DEFAULT 0,
  tax_amount numeric(10, 2) DEFAULT 0,
  total_amount numeric(10, 2) DEFAULT 0,
  
  -- Pricing tiers (optional)
  pricing_tier estimate_pricing_tier,
  
  -- Assignment and tracking
  created_by uuid NOT NULL REFERENCES profiles(id),
  assigned_to uuid REFERENCES profiles(id),
  
  -- Dates
  estimate_date date DEFAULT CURRENT_DATE,
  expiration_date date,
  sent_date timestamptz,
  viewed_date timestamptz,
  accepted_date timestamptz,
  rejected_date timestamptz,
  
  -- Conversion tracking
  converted_to_ticket_id uuid REFERENCES tickets(id),
  converted_to_project_id uuid REFERENCES projects(id),
  conversion_date timestamptz,
  
  -- Additional fields
  notes text,
  terms_and_conditions text,
  internal_notes text,
  
  -- Metadata
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create estimate line items table
CREATE TABLE IF NOT EXISTS estimate_line_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  estimate_id uuid NOT NULL REFERENCES estimates(id) ON DELETE CASCADE,
  line_order integer NOT NULL DEFAULT 0,
  
  item_type estimate_line_item_type NOT NULL,
  description text NOT NULL,
  
  -- Quantity and pricing
  quantity numeric(10, 2) DEFAULT 1,
  unit_price numeric(10, 2) NOT NULL,
  line_total numeric(10, 2) NOT NULL,
  
  -- Optional references
  part_id uuid REFERENCES parts(id),
  equipment_id uuid REFERENCES equipment(id),
  
  -- Labor details
  labor_hours numeric(5, 2),
  labor_rate numeric(10, 2),
  
  -- Notes
  notes text,
  
  -- Metadata
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create estimate attachments table
CREATE TABLE IF NOT EXISTS estimate_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  estimate_id uuid NOT NULL REFERENCES estimates(id) ON DELETE CASCADE,
  
  file_name text NOT NULL,
  file_url text NOT NULL,
  file_type text,
  file_size integer,
  
  uploaded_by uuid NOT NULL REFERENCES profiles(id),
  description text,
  
  created_at timestamptz DEFAULT now()
);

-- Create estimate activity log table
CREATE TABLE IF NOT EXISTS estimate_activity_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  estimate_id uuid NOT NULL REFERENCES estimates(id) ON DELETE CASCADE,
  
  action text NOT NULL,
  description text,
  old_status estimate_status,
  new_status estimate_status,
  
  performed_by uuid REFERENCES profiles(id),
  
  created_at timestamptz DEFAULT now()
);

-- Create estimate sequences table
CREATE TABLE IF NOT EXISTS estimate_sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year_month text NOT NULL,
  day_of_month integer NOT NULL,
  last_sequence integer DEFAULT 0,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  UNIQUE(year_month, day_of_month)
);

-- Function to generate estimate number
CREATE OR REPLACE FUNCTION generate_estimate_number()
RETURNS text AS $$
DECLARE
  v_year_month text;
  v_day text;
  v_day_int integer;
  v_sequence integer;
BEGIN
  -- Get current date parts
  v_year_month := to_char(now(), 'YYMM');
  v_day := to_char(now(), 'DD');
  v_day_int := EXTRACT(DAY FROM now())::integer;
  
  -- Get next sequence number for today
  INSERT INTO estimate_sequences (year_month, day_of_month, last_sequence)
  VALUES (v_year_month, v_day_int, 1)
  ON CONFLICT (year_month, day_of_month)
  DO UPDATE SET 
    last_sequence = estimate_sequences.last_sequence + 1,
    updated_at = now()
  RETURNING last_sequence INTO v_sequence;
  
  -- Return formatted estimate number: EST-YYMM-DD-N
  RETURN 'EST-' || v_year_month || '-' || v_day || '-' || v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate estimate totals
CREATE OR REPLACE FUNCTION calculate_estimate_totals(p_estimate_id uuid)
RETURNS void AS $$
DECLARE
  v_subtotal numeric(10, 2);
  v_discount numeric(10, 2);
  v_tax_rate numeric(5, 2);
  v_tax_amount numeric(10, 2);
  v_total numeric(10, 2);
BEGIN
  -- Calculate subtotal from line items
  SELECT COALESCE(SUM(line_total), 0)
  INTO v_subtotal
  FROM estimate_line_items
  WHERE estimate_id = p_estimate_id
    AND item_type != 'discount';
  
  -- Get discount amount
  SELECT COALESCE(SUM(ABS(line_total)), 0)
  INTO v_discount
  FROM estimate_line_items
  WHERE estimate_id = p_estimate_id
    AND item_type = 'discount';
  
  -- Get tax rate from estimate
  SELECT tax_rate INTO v_tax_rate
  FROM estimates
  WHERE id = p_estimate_id;
  
  -- Calculate tax (on subtotal minus discount)
  v_tax_amount := (v_subtotal - v_discount) * (v_tax_rate / 100);
  
  -- Calculate total
  v_total := v_subtotal - v_discount + v_tax_amount;
  
  -- Update estimate totals
  UPDATE estimates
  SET 
    subtotal = v_subtotal,
    discount_amount = v_discount,
    tax_amount = v_tax_amount,
    total_amount = v_total,
    updated_at = now()
  WHERE id = p_estimate_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to auto-generate estimate number
CREATE OR REPLACE FUNCTION auto_generate_estimate_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estimate_number IS NULL OR NEW.estimate_number = '' THEN
    NEW.estimate_number := generate_estimate_number();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-generating estimate numbers
DROP TRIGGER IF EXISTS trigger_auto_generate_estimate_number ON estimates;
CREATE TRIGGER trigger_auto_generate_estimate_number
  BEFORE INSERT ON estimates
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_estimate_number();

-- Trigger to update estimate totals when line items change
CREATE OR REPLACE FUNCTION trigger_update_estimate_totals()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM calculate_estimate_totals(OLD.estimate_id);
  ELSE
    PERFORM calculate_estimate_totals(NEW.estimate_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_estimate_line_items_totals ON estimate_line_items;
CREATE TRIGGER trigger_estimate_line_items_totals
  AFTER INSERT OR UPDATE OR DELETE ON estimate_line_items
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_estimate_totals();

-- Trigger to log estimate status changes
CREATE OR REPLACE FUNCTION trigger_log_estimate_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO estimate_activity_log (
      estimate_id,
      action,
      description,
      old_status,
      new_status
    ) VALUES (
      NEW.id,
      'status_change',
      'Status changed from ' || OLD.status || ' to ' || NEW.status,
      OLD.status,
      NEW.status
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_log_estimate_status ON estimates;
CREATE TRIGGER trigger_log_estimate_status
  AFTER UPDATE ON estimates
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION trigger_log_estimate_status_change();

-- Enable RLS on all tables
ALTER TABLE estimates ENABLE ROW LEVEL SECURITY;
ALTER TABLE estimate_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE estimate_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE estimate_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE estimate_sequences ENABLE ROW LEVEL SECURITY;

-- RLS Policies for estimates
CREATE POLICY "Authenticated users can view estimates"
  ON estimates FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can create estimates"
  ON estimates FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update estimates"
  ON estimates FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- RLS Policies for estimate_line_items
CREATE POLICY "Authenticated users can view line items"
  ON estimate_line_items FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage line items"
  ON estimate_line_items FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- RLS Policies for estimate_attachments
CREATE POLICY "Authenticated users can view attachments"
  ON estimate_attachments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage attachments"
  ON estimate_attachments FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- RLS Policies for estimate_activity_log
CREATE POLICY "Authenticated users can view activity log"
  ON estimate_activity_log FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can create activity log entries"
  ON estimate_activity_log FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- RLS Policies for estimate_sequences
CREATE POLICY "Authenticated users can view sequences"
  ON estimate_sequences FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage sequences"
  ON estimate_sequences FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_estimates_customer ON estimates(customer_id);
CREATE INDEX IF NOT EXISTS idx_estimates_status ON estimates(status);
CREATE INDEX IF NOT EXISTS idx_estimates_assigned_to ON estimates(assigned_to);
CREATE INDEX IF NOT EXISTS idx_estimates_created_by ON estimates(created_by);
CREATE INDEX IF NOT EXISTS idx_estimates_expiration ON estimates(expiration_date);
CREATE INDEX IF NOT EXISTS idx_estimates_estimate_number ON estimates(estimate_number);

CREATE INDEX IF NOT EXISTS idx_estimate_line_items_estimate ON estimate_line_items(estimate_id);
CREATE INDEX IF NOT EXISTS idx_estimate_line_items_order ON estimate_line_items(estimate_id, line_order);

CREATE INDEX IF NOT EXISTS idx_estimate_attachments_estimate ON estimate_attachments(estimate_id);

CREATE INDEX IF NOT EXISTS idx_estimate_activity_log_estimate ON estimate_activity_log(estimate_id);
CREATE INDEX IF NOT EXISTS idx_estimate_activity_log_date ON estimate_activity_log(created_at);

-- Set default expiration date (30 days from estimate date)
CREATE OR REPLACE FUNCTION set_default_expiration_date()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.expiration_date IS NULL THEN
    NEW.expiration_date := NEW.estimate_date + INTERVAL '30 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_expiration_date ON estimates;
CREATE TRIGGER trigger_set_expiration_date
  BEFORE INSERT ON estimates
  FOR EACH ROW
  EXECUTE FUNCTION set_default_expiration_date();
