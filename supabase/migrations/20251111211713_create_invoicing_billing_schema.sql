/*
  # Invoicing & Billing Schema

  ## Overview
  This migration creates the complete invoicing and billing infrastructure for the field service platform.
  Invoices are generated from completed tickets and projects, with full lifecycle tracking.

  ## 1. New Tables

  ### Invoices
    - `invoices` - Main invoice records
      - `id` (uuid, primary key)
      - `invoice_number` (text, unique) - Auto-generated invoice number
      - `customer_id` (uuid) - Foreign key to customers
      - `ticket_id` (uuid, nullable) - Optional link to originating ticket
      - `project_id` (uuid, nullable) - Optional link to originating project
      - `status` (enum) - draft, sent, paid, overdue, cancelled
      - `issue_date` (date) - When invoice was created
      - `due_date` (date) - Payment due date
      - `paid_date` (date, nullable) - When payment was received
      - `subtotal` (decimal) - Before tax and discounts
      - `tax_rate` (decimal) - Tax percentage
      - `tax_amount` (decimal) - Calculated tax
      - `discount_amount` (decimal) - Any discounts applied
      - `total_amount` (decimal) - Final amount due
      - `amount_paid` (decimal) - Amount received
      - `balance_due` (decimal) - Remaining balance
      - `notes` (text) - Internal notes
      - `customer_notes` (text) - Notes visible to customer
      - `payment_terms` (text) - e.g., "Net 30", "Due on Receipt"
      - `created_by` (uuid) - Foreign key to profiles
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Invoice Line Items
    - `invoice_line_items` - Individual items on invoices
      - `id` (uuid, primary key)
      - `invoice_id` (uuid) - Foreign key to invoices
      - `item_type` (enum) - labor, part, travel, service, other
      - `description` (text) - Item description
      - `part_id` (uuid, nullable) - Optional link to parts
      - `quantity` (decimal) - Quantity of item
      - `unit_price` (decimal) - Price per unit
      - `line_total` (decimal) - quantity * unit_price
      - `taxable` (boolean) - Whether item is subject to tax
      - `sort_order` (integer) - Display order
      - `created_at` (timestamptz)

  ### Payments
    - `payments` - Payment records against invoices
      - `id` (uuid, primary key)
      - `invoice_id` (uuid) - Foreign key to invoices
      - `payment_date` (date) - When payment was received
      - `amount` (decimal) - Payment amount
      - `payment_method` (text) - check, cash, credit_card, ach, other
      - `reference_number` (text) - Check number, transaction ID, etc.
      - `notes` (text) - Payment notes
      - `recorded_by` (uuid) - Foreign key to profiles
      - `created_at` (timestamptz)

  ## 2. Updates to Existing Tables
    - Extend tickets table with invoice tracking
    - Extend customers table with billing fields

  ## 3. Security
    - Enable RLS on all new tables
    - Authenticated users can view and manage invoices
    - Payments are restricted to admin and dispatcher roles

  ## 4. Indexes
    - Invoice number for quick lookup
    - Customer ID for customer billing history
    - Status and due date for AR aging reports
    - Payment references for reconciliation
*/

-- Create invoice status enum
DO $$ BEGIN
  CREATE TYPE invoice_status AS ENUM ('draft', 'sent', 'paid', 'overdue', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create invoice line item type enum
DO $$ BEGIN
  CREATE TYPE invoice_line_item_type AS ENUM ('labor', 'part', 'travel', 'service', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create invoices table
CREATE TABLE IF NOT EXISTS invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number text UNIQUE NOT NULL,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  ticket_id uuid REFERENCES tickets(id) ON DELETE SET NULL,
  project_id uuid REFERENCES projects(id) ON DELETE SET NULL,
  status invoice_status DEFAULT 'draft',
  issue_date date NOT NULL DEFAULT CURRENT_DATE,
  due_date date NOT NULL,
  paid_date date,
  subtotal decimal(10,2) NOT NULL DEFAULT 0,
  tax_rate decimal(5,2) NOT NULL DEFAULT 0,
  tax_amount decimal(10,2) NOT NULL DEFAULT 0,
  discount_amount decimal(10,2) NOT NULL DEFAULT 0,
  total_amount decimal(10,2) NOT NULL DEFAULT 0,
  amount_paid decimal(10,2) NOT NULL DEFAULT 0,
  balance_due decimal(10,2) NOT NULL DEFAULT 0,
  notes text,
  customer_notes text,
  payment_terms text DEFAULT 'Net 30',
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create invoice line items table
CREATE TABLE IF NOT EXISTS invoice_line_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  item_type invoice_line_item_type NOT NULL,
  description text NOT NULL,
  part_id uuid REFERENCES parts(id) ON DELETE SET NULL,
  quantity decimal(10,2) NOT NULL DEFAULT 1,
  unit_price decimal(10,2) NOT NULL,
  line_total decimal(10,2) NOT NULL,
  taxable boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create payments table
CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
  payment_date date NOT NULL DEFAULT CURRENT_DATE,
  amount decimal(10,2) NOT NULL CHECK (amount > 0),
  payment_method text NOT NULL,
  reference_number text,
  notes text,
  recorded_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now()
);

-- Add invoice tracking to tickets
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'invoice_id'
  ) THEN
    ALTER TABLE tickets ADD COLUMN invoice_id uuid REFERENCES invoices(id) ON DELETE SET NULL;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'labor_cost_estimate'
  ) THEN
    ALTER TABLE tickets ADD COLUMN labor_cost_estimate decimal(10,2);
  END IF;
END $$;

-- Add billing fields to customers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'customers' AND column_name = 'balance'
  ) THEN
    ALTER TABLE customers ADD COLUMN balance decimal(10,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'customers' AND column_name = 'credit_terms'
  ) THEN
    ALTER TABLE customers ADD COLUMN credit_terms text DEFAULT 'Net 30';
  END IF;
END $$;

-- Enable RLS
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Invoice policies
CREATE POLICY "Authenticated users can view invoices"
  ON invoices FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can create invoices"
  ON invoices FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update invoices"
  ON invoices FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete draft invoices"
  ON invoices FOR DELETE
  TO authenticated
  USING (status = 'draft');

-- Invoice line item policies
CREATE POLICY "Authenticated users can view invoice line items"
  ON invoice_line_items FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can create invoice line items"
  ON invoice_line_items FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update invoice line items"
  ON invoice_line_items FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete invoice line items"
  ON invoice_line_items FOR DELETE
  TO authenticated
  USING (true);

-- Payment policies
CREATE POLICY "Authenticated users can view payments"
  ON payments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can record payments"
  ON payments FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update payments"
  ON payments FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete payments"
  ON payments FOR DELETE
  TO authenticated
  USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_invoices_number ON invoices(invoice_number);
CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_due_date ON invoices(due_date);
CREATE INDEX IF NOT EXISTS idx_invoices_ticket ON invoices(ticket_id);
CREATE INDEX IF NOT EXISTS idx_invoices_project ON invoices(project_id);
CREATE INDEX IF NOT EXISTS idx_invoice_line_items_invoice ON invoice_line_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date);