/*
  # Auto Invoice Creation on Ticket Completion

  ## Overview
  Automatically creates invoices when service tickets are marked as completed.
  The system generates invoice line items for labor hours and parts used.

  ## 1. Features

  ### Invoice Generation
    - Triggers when ticket status changes to 'completed'
    - Generates unique invoice number (INV-YYYY-NNNN format)
    - Links invoice to ticket bidirectionally
    - Sets invoice dates and payment terms

  ### Invoice Line Items Created
    - **Labor**: Based on hours_onsite × labor rate
    - **Parts**: All parts used from ticket_parts_used table
    - Each line item includes description, quantity, price

  ## 2. Function: generate_invoice_number()
    - Creates sequential invoice numbers
    - Format: INV-2025-0001, INV-2025-0002, etc.
    - Resets yearly

  ## 3. Function: create_invoice_from_ticket()
    - Main trigger function
    - Creates invoice header
    - Adds labor line item
    - Adds parts line items
    - Calculates totals (subtotal, tax, total)
    - Updates ticket with invoice_id

  ## 4. Trigger: ticket_completion_invoice_trigger
    - Fires AFTER UPDATE on tickets table
    - Only when status changes TO 'completed'
    - Only if invoice doesn't already exist

  ## 5. Configuration
    - Default labor rate: $85/hour (configurable)
    - Default tax rate: 8.5% (configurable)
    - Payment terms: Net 30
    - Due date: 30 days from issue

  ## 6. Calculations
    - Subtotal = sum of all line items
    - Tax = subtotal × tax_rate (only on taxable items)
    - Total = subtotal + tax - discount
    - Balance due = total - amount paid
*/

-- Function to generate unique invoice numbers
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  year_part text;
  sequence_num integer;
  new_invoice_number text;
BEGIN
  year_part := TO_CHAR(CURRENT_DATE, 'YYYY');
  
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(invoice_number FROM 'INV-' || year_part || '-(\d+)') AS INTEGER)
  ), 0) + 1
  INTO sequence_num
  FROM invoices
  WHERE invoice_number LIKE 'INV-' || year_part || '-%';
  
  new_invoice_number := 'INV-' || year_part || '-' || LPAD(sequence_num::text, 4, '0');
  
  RETURN new_invoice_number;
END;
$$;

-- Function to create invoice from completed ticket
CREATE OR REPLACE FUNCTION create_invoice_from_ticket()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invoice_id uuid;
  v_invoice_number text;
  v_labor_rate numeric := 85.00;
  v_tax_rate numeric := 0.085;
  v_subtotal numeric := 0;
  v_tax_amount numeric := 0;
  v_total_amount numeric := 0;
  v_labor_cost numeric := 0;
  v_parts_cost numeric := 0;
  v_sort_order integer := 1;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') AND NEW.invoice_id IS NULL THEN
    
    v_invoice_id := gen_random_uuid();
    v_invoice_number := generate_invoice_number();
    
    v_labor_cost := COALESCE(NEW.hours_onsite, 0) * v_labor_rate;
    
    SELECT COALESCE(SUM(tpu.quantity * p.unit_price), 0)
    INTO v_parts_cost
    FROM ticket_parts_used tpu
    JOIN parts p ON p.id = tpu.part_id
    WHERE tpu.ticket_id = NEW.id;
    
    v_subtotal := v_labor_cost + v_parts_cost;
    v_tax_amount := v_subtotal * v_tax_rate;
    v_total_amount := v_subtotal + v_tax_amount;
    
    INSERT INTO invoices (
      id,
      invoice_number,
      customer_id,
      ticket_id,
      status,
      issue_date,
      due_date,
      subtotal,
      tax_rate,
      tax_amount,
      discount_amount,
      total_amount,
      amount_paid,
      balance_due,
      payment_terms,
      notes,
      created_by,
      created_at,
      updated_at
    ) VALUES (
      v_invoice_id,
      v_invoice_number,
      NEW.customer_id,
      NEW.id,
      'draft',
      CURRENT_DATE,
      CURRENT_DATE + INTERVAL '30 days',
      v_subtotal,
      v_tax_rate,
      v_tax_amount,
      0,
      v_total_amount,
      0,
      v_total_amount,
      'Net 30',
      'Auto-generated from ticket ' || NEW.ticket_number,
      NEW.created_by,
      NOW(),
      NOW()
    );
    
    IF v_labor_cost > 0 THEN
      INSERT INTO invoice_line_items (
        id,
        invoice_id,
        item_type,
        description,
        part_id,
        quantity,
        unit_price,
        line_total,
        taxable,
        sort_order,
        created_at
      ) VALUES (
        gen_random_uuid(),
        v_invoice_id,
        'labor',
        'Service Labor - ' || NEW.title || ' (' || COALESCE(NEW.hours_onsite, 0) || ' hours)',
        NULL,
        COALESCE(NEW.hours_onsite, 0),
        v_labor_rate,
        v_labor_cost,
        true,
        v_sort_order,
        NOW()
      );
      v_sort_order := v_sort_order + 1;
    END IF;
    
    INSERT INTO invoice_line_items (
      id,
      invoice_id,
      item_type,
      description,
      part_id,
      quantity,
      unit_price,
      line_total,
      taxable,
      sort_order,
      created_at
    )
    SELECT
      gen_random_uuid(),
      v_invoice_id,
      'part',
      p.part_name || ' (' || p.part_number || ')',
      tpu.part_id,
      tpu.quantity,
      p.unit_price,
      tpu.quantity * p.unit_price,
      true,
      v_sort_order + ROW_NUMBER() OVER (ORDER BY tpu.created_at),
      NOW()
    FROM ticket_parts_used tpu
    JOIN parts p ON p.id = tpu.part_id
    WHERE tpu.ticket_id = NEW.id;
    
    UPDATE tickets
    SET invoice_id = v_invoice_id,
        updated_at = NOW()
    WHERE id = NEW.id;
    
    NEW.invoice_id := v_invoice_id;
    
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for automatic invoice creation
DROP TRIGGER IF EXISTS ticket_completion_invoice_trigger ON tickets;

CREATE TRIGGER ticket_completion_invoice_trigger
  AFTER UPDATE ON tickets
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed'))
  EXECUTE FUNCTION create_invoice_from_ticket();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_invoice_number() TO authenticated;
GRANT EXECUTE ON FUNCTION create_invoice_from_ticket() TO authenticated;
