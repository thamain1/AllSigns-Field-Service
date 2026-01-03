/*
  # Add Import Batch Control Fields

  1. New Columns on import_batches
    - `is_cancel_requested` - Flag to signal import worker to stop processing
    - `is_rollback_requested` - Flag to track rollback requests
    - `supports_rollback` - Whether this batch can be rolled back (based on entity type)
    - `rolled_back_at` - Timestamp when rollback completed
    - `cancelled` phase already added in previous migration

  2. New Columns on Entity Tables
    - `import_batch_id` - Links created records back to their import batch for rollback capability
    - Added to: customers, customer_locations, invoices, invoice_line_items
    - Nullable and indexed for efficient rollback queries

  3. Purpose
    Enable safe cancel, rollback, and delete operations for import batches without breaking existing functionality

  ## Safety Features
  - All changes are additive (no columns removed)
  - Nullable fields don't affect existing records
  - Default values ensure backward compatibility
  - Indexes added for performance
*/

-- Add control fields to import_batches
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_batches' AND column_name = 'is_cancel_requested'
  ) THEN
    ALTER TABLE import_batches ADD COLUMN is_cancel_requested boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_batches' AND column_name = 'is_rollback_requested'
  ) THEN
    ALTER TABLE import_batches ADD COLUMN is_rollback_requested boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_batches' AND column_name = 'supports_rollback'
  ) THEN
    ALTER TABLE import_batches ADD COLUMN supports_rollback boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_batches' AND column_name = 'rolled_back_at'
  ) THEN
    ALTER TABLE import_batches ADD COLUMN rolled_back_at timestamptz;
  END IF;
END $$;

-- Add import_batch_id to customers table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'customers' AND column_name = 'import_batch_id'
  ) THEN
    ALTER TABLE customers ADD COLUMN import_batch_id uuid REFERENCES import_batches(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_customers_import_batch_id ON customers(import_batch_id);
  END IF;
END $$;

-- Add import_batch_id to customer_locations table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'customer_locations' AND column_name = 'import_batch_id'
  ) THEN
    ALTER TABLE customer_locations ADD COLUMN import_batch_id uuid REFERENCES import_batches(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_customer_locations_import_batch_id ON customer_locations(import_batch_id);
  END IF;
END $$;

-- Add import_batch_id to invoices table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'import_batch_id'
  ) THEN
    ALTER TABLE invoices ADD COLUMN import_batch_id uuid REFERENCES import_batches(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_invoices_import_batch_id ON invoices(import_batch_id);
  END IF;
END $$;

-- Add import_batch_id to invoice_line_items table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoice_line_items' AND column_name = 'import_batch_id'
  ) THEN
    ALTER TABLE invoice_line_items ADD COLUMN import_batch_id uuid REFERENCES import_batches(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_invoice_line_items_import_batch_id ON invoice_line_items(import_batch_id);
  END IF;
END $$;

-- Update 'cancelled' phase enum value (if not exists)
DO $$ BEGIN
  ALTER TYPE import_phase ADD VALUE IF NOT EXISTS 'cancelled';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Backfill supports_rollback based on entity_type
UPDATE import_batches
SET supports_rollback = CASE
  WHEN entity_type IN ('customers', 'ar') THEN true
  ELSE false  -- Future import types default to false until rollback is implemented
END
WHERE supports_rollback IS NULL;

-- Create function to check if a customer can be safely deleted
CREATE OR REPLACE FUNCTION can_rollback_customer(customer_id_param uuid)
RETURNS boolean AS $$
DECLARE
  has_tickets boolean;
  has_invoices boolean;
  has_estimates boolean;
BEGIN
  -- Check for tickets (created after import)
  SELECT EXISTS (
    SELECT 1 FROM tickets WHERE customer_id = customer_id_param
  ) INTO has_tickets;

  -- Check for invoices not from this import
  SELECT EXISTS (
    SELECT 1 FROM invoices 
    WHERE customer_id = customer_id_param 
    AND (import_batch_id IS NULL OR import_batch_id != (
      SELECT import_batch_id FROM customers WHERE id = customer_id_param
    ))
  ) INTO has_invoices;

  -- Check for estimates
  SELECT EXISTS (
    SELECT 1 FROM estimates WHERE customer_id = customer_id_param
  ) INTO has_estimates;

  RETURN NOT (has_tickets OR has_invoices OR has_estimates);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if an invoice can be safely deleted
CREATE OR REPLACE FUNCTION can_rollback_invoice(invoice_id_param uuid)
RETURNS boolean AS $$
DECLARE
  has_payments boolean;
  has_gl_entries boolean;
BEGIN
  -- Check for payment applications
  SELECT EXISTS (
    SELECT 1 FROM payment_applications WHERE invoice_id = invoice_id_param
  ) INTO has_payments;

  -- Check for GL entries (that weren't created by this import)
  SELECT EXISTS (
    SELECT 1 FROM gl_entries 
    WHERE reference_type = 'invoice' 
    AND reference_id = invoice_id_param
    AND (import_batch_id IS NULL OR import_batch_id != (
      SELECT import_batch_id FROM invoices WHERE id = invoice_id_param
    ))
  ) INTO has_gl_entries;

  RETURN NOT (has_payments OR has_gl_entries);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add import_batch_id to gl_entries (for accounting rollback)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'gl_entries' AND column_name = 'import_batch_id'
  ) THEN
    ALTER TABLE gl_entries ADD COLUMN import_batch_id uuid REFERENCES import_batches(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_gl_entries_import_batch_id ON gl_entries(import_batch_id);
  END IF;
END $$;

-- Create log table for rollback operations
CREATE TABLE IF NOT EXISTS import_rollback_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_batch_id uuid NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  action text NOT NULL,  -- 'deleted', 'skipped', 'reversed'
  reason text,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_import_rollback_logs_batch ON import_rollback_logs(import_batch_id);
CREATE INDEX IF NOT EXISTS idx_import_rollback_logs_created_at ON import_rollback_logs(created_at);

-- Enable RLS on rollback logs
ALTER TABLE import_rollback_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view rollback logs"
  ON import_rollback_logs FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can insert rollback logs"
  ON import_rollback_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
