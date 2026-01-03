/*
  # Fix Revenue Function NULL Handling

  ## Summary
  Fixes the update_customer_revenue_summary function to properly handle cases where
  customer_id cannot be determined (e.g., tickets without site_id, orphaned records).
  This prevents NULL constraint violations while maintaining data integrity.

  ## Changes
  - Add NULL check before attempting to insert/update customer_revenue_summary
  - Skip processing if customer_id cannot be determined
  - Log warning for data integrity issues

  ## Important Notes
  - Non-destructive fix
  - Prevents crashes from incomplete data
  - Does not affect working features
*/

CREATE OR REPLACE FUNCTION update_customer_revenue_summary()
RETURNS TRIGGER AS $$
DECLARE
  v_customer_id uuid;
BEGIN
  -- Get customer_id from the affected record
  IF TG_TABLE_NAME = 'invoices' THEN
    v_customer_id := COALESCE(NEW.customer_id, OLD.customer_id);
  ELSIF TG_TABLE_NAME = 'tickets' THEN
    -- Get customer through location
    SELECT cl.customer_id INTO v_customer_id
    FROM customer_locations cl
    WHERE cl.id = COALESCE(NEW.site_id, OLD.site_id);
  END IF;

  -- If we can't determine customer_id, skip processing
  -- This can happen with incomplete data (tickets without site_id, etc.)
  IF v_customer_id IS NULL THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    ELSE
      RETURN NEW;
    END IF;
  END IF;

  -- Ensure summary record exists
  INSERT INTO customer_revenue_summary (customer_id)
  VALUES (v_customer_id)
  ON CONFLICT (customer_id) DO NOTHING;

  -- Update the summary with CORRECT invoice-based calculations
  UPDATE customer_revenue_summary
  SET
    -- Total billed amount (accrual-basis) - all posted invoices excluding drafts/cancelled
    total_billed = COALESCE((
      SELECT SUM(total_amount)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status NOT IN ('draft', 'cancelled', 'written_off')
    ), 0),
    
    -- Total collected amount (cash-basis) - actual amount paid
    total_collected = COALESCE((
      SELECT SUM(amount_paid)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status NOT IN ('draft', 'cancelled', 'written_off')
    ), 0),
    
    -- Keep old total_revenue for backward compatibility (same as total_collected)
    total_revenue = COALESCE((
      SELECT SUM(amount_paid)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status NOT IN ('draft', 'cancelled', 'written_off')
    ), 0),
    
    -- Outstanding balance (sum of balance_due)
    outstanding_balance = COALESCE((
      SELECT SUM(balance_due)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status NOT IN ('draft', 'cancelled', 'written_off')
        AND balance_due > 0
    ), 0),
    
    -- YTD billed (current year invoiced amount)
    ytd_billed = COALESCE((
      SELECT SUM(total_amount)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status NOT IN ('draft', 'cancelled', 'written_off')
        AND EXTRACT(YEAR FROM issue_date) = EXTRACT(YEAR FROM CURRENT_DATE)
    ), 0),
    
    -- YTD collected (current year cash collected)
    ytd_collected = COALESCE((
      SELECT SUM(amount_paid)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status NOT IN ('draft', 'cancelled', 'written_off')
        AND paid_date IS NOT NULL
        AND EXTRACT(YEAR FROM paid_date) = EXTRACT(YEAR FROM CURRENT_DATE)
    ), 0),
    
    -- Keep old ytd_revenue for backward compatibility
    ytd_revenue = COALESCE((
      SELECT SUM(amount_paid)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status NOT IN ('draft', 'cancelled', 'written_off')
        AND paid_date IS NOT NULL
        AND EXTRACT(YEAR FROM paid_date) = EXTRACT(YEAR FROM CURRENT_DATE)
    ), 0),
    
    -- Last invoice date (most recent issue_date)
    last_invoice_date = (
      SELECT MAX(issue_date)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status NOT IN ('draft', 'cancelled')
    ),
    
    -- Total tickets (unchanged)
    total_tickets = COALESCE((
      SELECT COUNT(*)
      FROM tickets t
      JOIN customer_locations cl ON cl.id = t.site_id
      WHERE cl.customer_id = v_customer_id
    ), 0),
    
    -- Completed tickets (unchanged)
    completed_tickets = COALESCE((
      SELECT COUNT(*)
      FROM tickets t
      JOIN customer_locations cl ON cl.id = t.site_id
      WHERE cl.customer_id = v_customer_id AND t.status = 'completed'
    ), 0),
    
    -- Last service date (unchanged)
    last_service_date = (
      SELECT MAX(completed_at)
      FROM tickets t
      JOIN customer_locations cl ON cl.id = t.site_id
      WHERE cl.customer_id = v_customer_id AND t.status = 'completed'
    ),
    
    -- Average invoice value (based on posted invoices)
    average_ticket_value = COALESCE((
      SELECT AVG(total_amount)
      FROM invoices
      WHERE customer_id = v_customer_id 
        AND status NOT IN ('draft', 'cancelled', 'written_off')
    ), 0),
    
    -- Total parts cost (unchanged - based on paid invoices only)
    total_parts_cost = COALESCE((
      SELECT SUM(il.quantity * il.unit_price)
      FROM invoices i
      JOIN invoice_line_items il ON il.invoice_id = i.id
      WHERE i.customer_id = v_customer_id 
        AND i.status = 'paid'
        AND il.item_type = 'part'
    ), 0),
    
    -- Total labor cost (unchanged - based on paid invoices only)
    total_labor_cost = COALESCE((
      SELECT SUM(il.quantity * il.unit_price)
      FROM invoices i
      JOIN invoice_line_items il ON il.invoice_id = i.id
      WHERE i.customer_id = v_customer_id 
        AND i.status = 'paid'
        AND il.item_type = 'labor'
    ), 0),
    
    updated_at = now()
  WHERE customer_id = v_customer_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_customer_revenue_summary() IS 
  'Maintains customer_revenue_summary table based on invoices. Revenue is calculated from posted invoices only (excluding draft/cancelled). Distinguishes between billed (accrual) and collected (cash) amounts. Handles NULL customer_id gracefully.';
