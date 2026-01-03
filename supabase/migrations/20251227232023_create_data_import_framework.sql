/*
  # Data Import Framework Schema

  This migration creates the infrastructure for importing data from external ERP systems.

  ## New Tables

  ### 1. `import_batches`
  Tracks each import session with metadata and status
  - `id` (uuid, primary key)
  - `batch_number` (text, auto-generated)
  - `entity_type` (enum: customers, ar, vendors, items, history)
  - `file_name` (text)
  - `file_size` (bigint)
  - `file_encoding` (text)
  - `status` (enum: pending, validating, validated, importing, completed, failed, rolled_back)
  - `mapping_config` (jsonb) - stores column mapping configuration
  - `created_by` (uuid, foreign key to profiles)
  - `started_at` (timestamptz)
  - `completed_at` (timestamptz)
  - `rows_total` (integer)
  - `rows_valid` (integer)
  - `rows_error` (integer)
  - `rows_imported` (integer)
  - `error_summary` (text)

  ### 2. `import_customers_staging`
  Temporary staging for customer import data
  - `id` (uuid, primary key)
  - `import_batch_id` (uuid, foreign key)
  - `row_number` (integer)
  - `raw_row_json` (jsonb) - original CSV row data
  - `external_customer_id` (text)
  - `name` (text)
  - `email` (text)
  - `phone` (text)
  - `address` (text)
  - `city` (text)
  - `state` (text)
  - `zip_code` (text)
  - `customer_type` (text)
  - `notes` (text)
  - `validation_status` (enum: pending, valid, error)
  - `validation_errors` (jsonb)
  - `imported_customer_id` (uuid) - reference to created customer
  - `imported_at` (timestamptz)

  ### 3. `import_ar_staging`
  Temporary staging for AR/invoice import data
  - `id` (uuid, primary key)
  - `import_batch_id` (uuid, foreign key)
  - `row_number` (integer)
  - `raw_row_json` (jsonb)
  - `external_customer_id` (text)
  - `external_invoice_number` (text)
  - `invoice_amount` (numeric)
  - `balance_due` (numeric)
  - `current_amount` (numeric)
  - `days_1_30` (numeric)
  - `days_31_60` (numeric)
  - `days_61_90` (numeric)
  - `days_90_plus` (numeric)
  - `issue_date` (date)
  - `due_date` (date)
  - `aging_bucket` (text)
  - `description` (text)
  - `validation_status` (enum: pending, valid, error)
  - `validation_errors` (jsonb)
  - `imported_customer_id` (uuid)
  - `imported_invoice_id` (uuid)
  - `imported_at` (timestamptz)

  ### 4. `import_logs`
  Detailed logging for each import operation
  - `id` (uuid, primary key)
  - `import_batch_id` (uuid, foreign key)
  - `log_level` (enum: info, warning, error)
  - `message` (text)
  - `details` (jsonb)
  - `created_at` (timestamptz)

  ## Modified Tables (Additive Only)

  ### `customers`
  - Add `external_customer_id` (text) - ID from source ERP system
  - Add `import_batch_id` (uuid) - which import created this record
  - Add `imported_at` (timestamptz)

  ### `invoices`
  - Add `external_invoice_number` (text) - invoice # from source system
  - Add `is_migrated_opening_balance` (boolean, default false) - marks imported AR
  - Add `is_historical` (boolean, default false) - marks historical data
  - Add `import_batch_id` (uuid)
  - Add `imported_at` (timestamptz)

  ## Security
  - Enable RLS on all staging tables
  - Only admins can create/manage imports
  - All tables track who initiated the import
*/

-- Create enums for import framework
DO $$ BEGIN
  CREATE TYPE import_entity_type AS ENUM ('customers', 'ar', 'vendors', 'items', 'history');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE import_batch_status AS ENUM ('pending', 'validating', 'validated', 'importing', 'completed', 'failed', 'rolled_back');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE import_validation_status AS ENUM ('pending', 'valid', 'error');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE import_log_level AS ENUM ('info', 'warning', 'error');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create import_batches table
CREATE TABLE IF NOT EXISTS import_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_number text UNIQUE NOT NULL,
  entity_type import_entity_type NOT NULL,
  file_name text NOT NULL,
  file_size bigint,
  file_encoding text DEFAULT 'utf-8',
  status import_batch_status DEFAULT 'pending' NOT NULL,
  mapping_config jsonb DEFAULT '{}'::jsonb,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  started_at timestamptz DEFAULT now(),
  completed_at timestamptz,
  rows_total integer DEFAULT 0,
  rows_valid integer DEFAULT 0,
  rows_error integer DEFAULT 0,
  rows_imported integer DEFAULT 0,
  error_summary text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create import_customers_staging table
CREATE TABLE IF NOT EXISTS import_customers_staging (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_batch_id uuid NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
  row_number integer NOT NULL,
  raw_row_json jsonb NOT NULL,
  external_customer_id text,
  name text,
  email text,
  phone text,
  address text,
  city text,
  state text,
  zip_code text,
  customer_type text,
  notes text,
  validation_status import_validation_status DEFAULT 'pending',
  validation_errors jsonb DEFAULT '[]'::jsonb,
  imported_customer_id uuid,
  imported_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create import_ar_staging table
CREATE TABLE IF NOT EXISTS import_ar_staging (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_batch_id uuid NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
  row_number integer NOT NULL,
  raw_row_json jsonb NOT NULL,
  external_customer_id text,
  external_invoice_number text,
  invoice_amount numeric(12, 2),
  balance_due numeric(12, 2),
  current_amount numeric(12, 2) DEFAULT 0,
  days_1_30 numeric(12, 2) DEFAULT 0,
  days_31_60 numeric(12, 2) DEFAULT 0,
  days_61_90 numeric(12, 2) DEFAULT 0,
  days_90_plus numeric(12, 2) DEFAULT 0,
  issue_date date,
  due_date date,
  aging_bucket text,
  description text,
  validation_status import_validation_status DEFAULT 'pending',
  validation_errors jsonb DEFAULT '[]'::jsonb,
  imported_customer_id uuid,
  imported_invoice_id uuid,
  imported_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create import_logs table
CREATE TABLE IF NOT EXISTS import_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_batch_id uuid NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
  log_level import_log_level DEFAULT 'info',
  message text NOT NULL,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Add external tracking columns to customers (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'customers' AND column_name = 'external_customer_id'
  ) THEN
    ALTER TABLE customers ADD COLUMN external_customer_id text;
    CREATE INDEX IF NOT EXISTS idx_customers_external_id ON customers(external_customer_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'customers' AND column_name = 'import_batch_id'
  ) THEN
    ALTER TABLE customers ADD COLUMN import_batch_id uuid REFERENCES import_batches(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'customers' AND column_name = 'imported_at'
  ) THEN
    ALTER TABLE customers ADD COLUMN imported_at timestamptz;
  END IF;
END $$;

-- Add external tracking columns to invoices (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'external_invoice_number'
  ) THEN
    ALTER TABLE invoices ADD COLUMN external_invoice_number text;
    CREATE INDEX IF NOT EXISTS idx_invoices_external_number ON invoices(external_invoice_number);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'is_migrated_opening_balance'
  ) THEN
    ALTER TABLE invoices ADD COLUMN is_migrated_opening_balance boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'is_historical'
  ) THEN
    ALTER TABLE invoices ADD COLUMN is_historical boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'import_batch_id'
  ) THEN
    ALTER TABLE invoices ADD COLUMN import_batch_id uuid REFERENCES import_batches(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'imported_at'
  ) THEN
    ALTER TABLE invoices ADD COLUMN imported_at timestamptz;
  END IF;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_import_batches_status ON import_batches(status);
CREATE INDEX IF NOT EXISTS idx_import_batches_entity_type ON import_batches(entity_type);
CREATE INDEX IF NOT EXISTS idx_import_batches_created_by ON import_batches(created_by);
CREATE INDEX IF NOT EXISTS idx_import_customers_staging_batch ON import_customers_staging(import_batch_id);
CREATE INDEX IF NOT EXISTS idx_import_customers_staging_validation ON import_customers_staging(validation_status);
CREATE INDEX IF NOT EXISTS idx_import_ar_staging_batch ON import_ar_staging(import_batch_id);
CREATE INDEX IF NOT EXISTS idx_import_ar_staging_validation ON import_ar_staging(validation_status);
CREATE INDEX IF NOT EXISTS idx_import_logs_batch ON import_logs(import_batch_id);

-- Function to generate batch numbers
CREATE OR REPLACE FUNCTION generate_import_batch_number()
RETURNS text AS $$
DECLARE
  new_number text;
  counter integer := 1;
BEGIN
  LOOP
    new_number := 'IMP-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(counter::text, 4, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM import_batches WHERE batch_number = new_number
    );
    counter := counter + 1;
  END LOOP;
  RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate batch numbers
CREATE OR REPLACE FUNCTION set_import_batch_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.batch_number IS NULL OR NEW.batch_number = '' THEN
    NEW.batch_number := generate_import_batch_number();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_import_batch_number ON import_batches;
CREATE TRIGGER trigger_set_import_batch_number
  BEFORE INSERT ON import_batches
  FOR EACH ROW
  EXECUTE FUNCTION set_import_batch_number();

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_import_batch_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_import_batch_timestamp ON import_batches;
CREATE TRIGGER trigger_update_import_batch_timestamp
  BEFORE UPDATE ON import_batches
  FOR EACH ROW
  EXECUTE FUNCTION update_import_batch_timestamp();

-- Enable RLS on all import tables
ALTER TABLE import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_customers_staging ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_ar_staging ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Only admins can manage imports
CREATE POLICY "Admins can view all import batches"
  ON import_batches FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can create import batches"
  ON import_batches FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can update import batches"
  ON import_batches FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete import batches"
  ON import_batches FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Similar policies for staging tables
CREATE POLICY "Admins can view customer staging"
  ON import_customers_staging FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can manage customer staging"
  ON import_customers_staging FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can view AR staging"
  ON import_ar_staging FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can manage AR staging"
  ON import_ar_staging FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can view import logs"
  ON import_logs FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can create import logs"
  ON import_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
