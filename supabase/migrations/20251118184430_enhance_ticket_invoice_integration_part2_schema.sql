/*
  # Ticket-Invoice Integration - Part 2: Schema Changes

  ## Overview
  Adds columns and tables to support tight ticket-invoice integration.

  ## Changes
  1. Enhance tickets table with billing fields
  2. Enhance invoices table with source tracking
  3. Enhance invoice_line_items with traceability
  4. Create ticket_invoice_links many-to-many table
*/

-- =====================================================
-- 1. Enhance tickets table
-- =====================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'billable'
  ) THEN
    ALTER TABLE tickets ADD COLUMN billable boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'billed_amount'
  ) THEN
    ALTER TABLE tickets ADD COLUMN billed_amount numeric(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'site_id'
  ) THEN
    ALTER TABLE tickets ADD COLUMN site_id uuid REFERENCES customers(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'ready_to_invoice_at'
  ) THEN
    ALTER TABLE tickets ADD COLUMN ready_to_invoice_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'billed_at'
  ) THEN
    ALTER TABLE tickets ADD COLUMN billed_at timestamptz;
  END IF;
END $$;

-- Create index on billable tickets ready for invoicing
CREATE INDEX IF NOT EXISTS idx_tickets_ready_to_invoice 
ON tickets(status, billable) 
WHERE status = 'ready_to_invoice' AND billable = true;

-- =====================================================
-- 2. Enhance invoices table
-- =====================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'invoices' AND column_name = 'site_id'
  ) THEN
    ALTER TABLE invoices ADD COLUMN site_id uuid REFERENCES customers(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'invoices' AND column_name = 'source_type'
  ) THEN
    ALTER TABLE invoices ADD COLUMN source_type invoice_source_type DEFAULT 'SVC';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'invoices' AND column_name = 'source_ticket_id'
  ) THEN
    ALTER TABLE invoices ADD COLUMN source_ticket_id uuid REFERENCES tickets(id);
  END IF;
END $$;

-- Create index for quick invoice lookups by ticket
CREATE INDEX IF NOT EXISTS idx_invoices_source_ticket 
ON invoices(source_ticket_id) 
WHERE source_ticket_id IS NOT NULL;

-- =====================================================
-- 3. Enhance invoice_line_items table
-- =====================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'invoice_line_items' AND column_name = 'ticket_id'
  ) THEN
    ALTER TABLE invoice_line_items ADD COLUMN ticket_id uuid REFERENCES tickets(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'invoice_line_items' AND column_name = 'project_id'
  ) THEN
    ALTER TABLE invoice_line_items ADD COLUMN project_id uuid REFERENCES projects(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'invoice_line_items' AND column_name = 'project_task_id'
  ) THEN
    ALTER TABLE invoice_line_items ADD COLUMN project_task_id uuid;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'invoice_line_items' AND column_name = 'time_log_id'
  ) THEN
    ALTER TABLE invoice_line_items ADD COLUMN time_log_id uuid REFERENCES time_logs(id);
  END IF;
END $$;

-- Create indexes for traceability queries
CREATE INDEX IF NOT EXISTS idx_invoice_line_items_ticket 
ON invoice_line_items(ticket_id) 
WHERE ticket_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_invoice_line_items_project 
ON invoice_line_items(project_id) 
WHERE project_id IS NOT NULL;

-- =====================================================
-- 4. Create ticket_invoice_links table (Many-to-Many)
-- =====================================================

CREATE TABLE IF NOT EXISTS ticket_invoice_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  amount_contributed numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(ticket_id, invoice_id)
);

ALTER TABLE ticket_invoice_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view ticket invoice links"
  ON ticket_invoice_links FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins and dispatchers can manage ticket invoice links"
  ON ticket_invoice_links FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

CREATE INDEX IF NOT EXISTS idx_ticket_invoice_links_ticket 
ON ticket_invoice_links(ticket_id);

CREATE INDEX IF NOT EXISTS idx_ticket_invoice_links_invoice 
ON ticket_invoice_links(invoice_id);

-- =====================================================
-- 5. Add column comments
-- =====================================================

COMMENT ON COLUMN tickets.billable IS 'Whether this ticket should be billed to the customer (false for warranty/contract work)';
COMMENT ON COLUMN tickets.billed_amount IS 'Total amount billed for this ticket across all invoices';
COMMENT ON COLUMN tickets.site_id IS 'Customer site/location where work was performed';
COMMENT ON COLUMN tickets.ready_to_invoice_at IS 'Timestamp when ticket was marked ready to invoice';
COMMENT ON COLUMN tickets.billed_at IS 'Timestamp when ticket was marked as billed';

COMMENT ON COLUMN invoices.source_type IS 'Type of work: SVC (single service ticket), PRJ (project), or Mixed (multiple tickets)';
COMMENT ON COLUMN invoices.source_ticket_id IS 'Primary ticket for 1:1 SVC invoices';
COMMENT ON COLUMN invoices.site_id IS 'Customer site where work was performed';

COMMENT ON TABLE ticket_invoice_links IS 'Many-to-many relationship tracking how much each ticket contributed to each invoice';
COMMENT ON COLUMN ticket_invoice_links.amount_contributed IS 'Portion of invoice total attributable to this ticket';
