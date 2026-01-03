/*
  # Update Invoice Trigger to Use Accounting Settings

  ## Overview
  Updates the automatic invoice creation trigger to pull labor rates
  and tax rates from the accounting_settings table instead of using
  hardcoded values.

  ## Changes
    - Modified create_invoice_from_ticket() function
    - Now reads default_labor_rate from settings
    - Now reads default_tax_rate from settings
    - Now reads default_payment_terms from settings
    - Now reads invoice_due_days from settings
    - Falls back to original defaults if settings not found

  ## Benefits
    - Settings can be changed without migration
    - Centralized configuration management
    - No code changes needed for rate updates
*/

-- Update the invoice creation function to use settings
CREATE OR REPLACE FUNCTION create_invoice_from_ticket()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invoice_id uuid;
  v_invoice_number text;
  v_labor_rate numeric;
  v_tax_rate numeric;
  v_payment_terms text;
  v_due_days integer;
  v_subtotal numeric := 0;
  v_tax_amount numeric := 0;
  v_total_amount numeric := 0;
  v_labor_cost numeric := 0;
  v_parts_cost numeric := 0;
  v_sort_order integer := 1;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') AND NEW.invoice_id IS NULL THEN
    
    -- Get settings from accounting_settings table with fallback defaults
    v_labor_rate := get_accounting_setting_numeric('default_labor_rate', 85.00);
    v_tax_rate := get_accounting_setting_numeric('default_tax_rate', 8.5) / 100.0;
    v_payment_terms := get_accounting_setting('default_payment_terms', 'Net 30');
    v_due_days := get_accounting_setting_numeric('invoice_due_days', 30)::integer;
    
    v_invoice_id := gen_random_uuid();
    v_invoice_number := generate_invoice_number();
    
    -- Calculate labor cost
    v_labor_cost := COALESCE(NEW.hours_onsite, 0) * v_labor_rate;
    
    -- Calculate parts cost
    SELECT COALESCE(SUM(tpu.quantity * p.unit_price), 0)
    INTO v_parts_cost
    FROM ticket_parts_used tpu
    JOIN parts p ON p.id = tpu.part_id
    WHERE tpu.ticket_id = NEW.id;
    
    -- Calculate totals
    v_subtotal := v_labor_cost + v_parts_cost;
    v_tax_amount := v_subtotal * v_tax_rate;
    v_total_amount := v_subtotal + v_tax_amount;
    
    -- Create invoice header
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
      CURRENT_DATE + (v_due_days || ' days')::interval,
      v_subtotal,
      v_tax_rate,
      v_tax_amount,
      0,
      v_total_amount,
      0,
      v_total_amount,
      v_payment_terms,
      'Auto-generated from ticket ' || NEW.ticket_number,
      NEW.created_by,
      NOW(),
      NOW()
    );
    
    -- Add labor line item if applicable
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
        'Service Labor - ' || NEW.title || ' (' || COALESCE(NEW.hours_onsite, 0) || ' hours @ $' || v_labor_rate || '/hr)',
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
    
    -- Add parts line items
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
    
    -- Update ticket with invoice_id
    UPDATE tickets
    SET invoice_id = v_invoice_id,
        updated_at = NOW()
    WHERE id = NEW.id;
    
    NEW.invoice_id := v_invoice_id;
    
  END IF;
  
  RETURN NEW;
END;
$$;
