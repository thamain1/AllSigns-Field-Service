/*
  # Add Deposit Tracking to Invoice Line Items

  1. Additive Columns to invoice_line_items
    - is_deposit - Flag for deposit/advance payment line items
    - is_retainage - Flag for retainage line items
    - project_billing_schedule_id - Link to milestone being billed

  2. Important Notes
    - All columns nullable to preserve existing data
    - Existing invoice lines remain unchanged
    - No destructive changes
*/

-- Add deposit tracking flag
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoice_line_items' AND column_name = 'is_deposit'
  ) THEN
    ALTER TABLE invoice_line_items ADD COLUMN is_deposit boolean DEFAULT false;
  END IF;
END $$;

-- Add retainage tracking flag
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoice_line_items' AND column_name = 'is_retainage'
  ) THEN
    ALTER TABLE invoice_line_items ADD COLUMN is_retainage boolean DEFAULT false;
  END IF;
END $$;

-- Link to billing schedule milestone
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoice_line_items' AND column_name = 'project_billing_schedule_id'
  ) THEN
    ALTER TABLE invoice_line_items 
    ADD COLUMN project_billing_schedule_id uuid 
    REFERENCES project_billing_schedules(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Create index for billing schedule lookups
CREATE INDEX IF NOT EXISTS idx_invoice_line_items_billing_schedule 
  ON invoice_line_items(project_billing_schedule_id) 
  WHERE project_billing_schedule_id IS NOT NULL;

-- Create index for deposit queries
CREATE INDEX IF NOT EXISTS idx_invoice_line_items_is_deposit 
  ON invoice_line_items(invoice_id, is_deposit) 
  WHERE is_deposit = true;

-- Add helpful comments
COMMENT ON COLUMN invoice_line_items.is_deposit IS 'TRUE for deposit/advance payment line items that should post to Contract Liability instead of Revenue';
COMMENT ON COLUMN invoice_line_items.is_retainage IS 'TRUE for retainage line items';
COMMENT ON COLUMN invoice_line_items.project_billing_schedule_id IS 'Links this line item to a specific project milestone';
