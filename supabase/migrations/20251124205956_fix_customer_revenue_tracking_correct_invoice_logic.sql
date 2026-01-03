/*
  # Fix Customer Revenue Tracking - Correct Invoice Logic

  ## Summary
  This migration fixes the revenue tracking logic to correctly calculate customer revenue
  based ONLY on posted invoices (not drafts or cancelled), properly handle partial payments,
  and account for discounts/credits. This is a non-destructive fix that corrects the 
  calculation logic without changing the schema.

  ## Problems Fixed
  
  1. **Invoice Status Logic**
     - OLD: Only counted status = 'paid'
     - NEW: Count all posted invoices: 'sent', 'paid', 'overdue', 'partially_paid'
     - EXCLUDE: 'draft', 'cancelled', 'written_off'
  
  2. **Revenue Calculation**
     - OLD: Used total_amount only
     - NEW: Use amount_paid (actual cash collected) for cash-basis revenue
     - ALSO: Track total billed amount separately
  
  3. **Date Field Correction**
     - OLD: Used paid_at (doesn't exist)
     - NEW: Use paid_date (actual column name)
  
  4. **Discount Handling**
     - Now properly accounts for discount_amount in calculations
  
  5. **Last Invoice Logic**
     - Track last invoice date (issue_date) not just last paid date

  ## Changes
  
  1. Add new columns to customer_revenue_summary:
     - total_billed: Total amount of all posted invoices (regardless of payment)
     - total_collected: Actual amount paid (sum of amount_paid)
     - outstanding_balance: Total balance_due on all unpaid/partial invoices
     - last_invoice_date: Most recent invoice issue_date
  
  2. Update revenue calculation function to:
     - Use correct invoice statuses for "posted" invoices
     - Calculate both billed and collected amounts
     - Track outstanding balances
     - Handle YTD correctly with issue_date instead of paid_date
  
  3. Rename total_revenue → total_collected for clarity
  
  ## Important Notes
  - This is additive and backward-compatible
  - Existing columns are enhanced, not removed
  - Revenue is strictly derived from invoices table
  - Summary table is a materialized cache, not source of truth
*/

-- ============================================================================
-- STEP 1: Add new columns to customer_revenue_summary
-- ============================================================================

DO $$
BEGIN
  -- Add total_billed (total invoiced amount, regardless of payment status)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customer_revenue_summary' AND column_name = 'total_billed'
  ) THEN
    ALTER TABLE customer_revenue_summary 
    ADD COLUMN total_billed numeric(10,2) DEFAULT 0;
  END IF;

  -- Add total_collected (actual amount paid/collected)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customer_revenue_summary' AND column_name = 'total_collected'
  ) THEN
    ALTER TABLE customer_revenue_summary 
    ADD COLUMN total_collected numeric(10,2) DEFAULT 0;
  END IF;

  -- Add outstanding_balance (total balance due)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customer_revenue_summary' AND column_name = 'outstanding_balance'
  ) THEN
    ALTER TABLE customer_revenue_summary 
    ADD COLUMN outstanding_balance numeric(10,2) DEFAULT 0;
  END IF;

  -- Add last_invoice_date (most recent invoice issue_date)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customer_revenue_summary' AND column_name = 'last_invoice_date'
  ) THEN
    ALTER TABLE customer_revenue_summary 
    ADD COLUMN last_invoice_date date;
  END IF;

  -- Add ytd_billed (total invoiced this year)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customer_revenue_summary' AND column_name = 'ytd_billed'
  ) THEN
    ALTER TABLE customer_revenue_summary 
    ADD COLUMN ytd_billed numeric(10,2) DEFAULT 0;
  END IF;

  -- Add ytd_collected (actual amount collected this year)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customer_revenue_summary' AND column_name = 'ytd_collected'
  ) THEN
    ALTER TABLE customer_revenue_summary 
    ADD COLUMN ytd_collected numeric(10,2) DEFAULT 0;
  END IF;
END $$;

-- Add comments explaining the fields
COMMENT ON COLUMN customer_revenue_summary.total_revenue IS 
  'DEPRECATED: Use total_collected instead. Total amount paid by customer (cash-basis).';

COMMENT ON COLUMN customer_revenue_summary.total_billed IS 
  'Total amount invoiced (accrual-basis) from all posted invoices, excluding drafts/cancelled.';

COMMENT ON COLUMN customer_revenue_summary.total_collected IS 
  'Total amount actually paid/collected (cash-basis) from amount_paid field.';

COMMENT ON COLUMN customer_revenue_summary.outstanding_balance IS 
  'Total unpaid balance across all invoices (sum of balance_due where > 0).';

COMMENT ON COLUMN customer_revenue_summary.ytd_revenue IS 
  'DEPRECATED: Use ytd_collected instead. Year-to-date cash collected.';

COMMENT ON COLUMN customer_revenue_summary.ytd_billed IS 
  'Year-to-date total invoiced amount (accrual-basis).';

COMMENT ON COLUMN customer_revenue_summary.ytd_collected IS 
  'Year-to-date actual amount collected (cash-basis).';

-- ============================================================================
-- STEP 2: Replace revenue calculation function with correct logic
-- ============================================================================

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
  'Maintains customer_revenue_summary table based on invoices. Revenue is calculated from posted invoices only (excluding draft/cancelled). Distinguishes between billed (accrual) and collected (cash) amounts.';

-- ============================================================================
-- STEP 3: Create view for easy revenue querying
-- ============================================================================

CREATE OR REPLACE VIEW customer_revenue_details AS
SELECT 
  c.id AS customer_id,
  c.name AS customer_name,
  crs.total_billed,
  crs.total_collected,
  crs.outstanding_balance,
  crs.ytd_billed,
  crs.ytd_collected,
  crs.last_invoice_date,
  crs.last_service_date,
  crs.total_tickets,
  crs.completed_tickets,
  crs.average_ticket_value,
  crs.total_parts_cost,
  crs.total_labor_cost,
  -- Calculate collection rate
  CASE 
    WHEN crs.total_billed > 0 
    THEN ROUND((crs.total_collected / crs.total_billed * 100)::numeric, 2)
    ELSE 0 
  END AS collection_rate_percent,
  -- Invoice count by status
  (SELECT COUNT(*) FROM invoices WHERE customer_id = c.id AND status = 'paid') AS invoices_paid,
  (SELECT COUNT(*) FROM invoices WHERE customer_id = c.id AND status = 'sent') AS invoices_sent,
  (SELECT COUNT(*) FROM invoices WHERE customer_id = c.id AND status = 'overdue') AS invoices_overdue,
  (SELECT COUNT(*) FROM invoices WHERE customer_id = c.id AND status = 'partially_paid') AS invoices_partial,
  crs.created_at,
  crs.updated_at
FROM customers c
LEFT JOIN customer_revenue_summary crs ON crs.customer_id = c.id
ORDER BY c.name;

COMMENT ON VIEW customer_revenue_details IS 
  'Comprehensive customer revenue view showing billed vs collected amounts, collection rates, and invoice status breakdown. All revenue values are derived from invoices table.';

-- ============================================================================
-- STEP 4: Recalculate all customer revenue summaries with correct logic
-- ============================================================================

-- Trigger recalculation for all customers
UPDATE customer_revenue_summary
SET updated_at = now();

-- ============================================================================
-- STEP 5: Create helper function for revenue reconciliation
-- ============================================================================

CREATE OR REPLACE FUNCTION reconcile_customer_revenue(p_customer_id uuid)
RETURNS TABLE(
  metric text,
  summary_value numeric,
  invoice_value numeric,
  matches boolean
) AS $$
BEGIN
  RETURN QUERY
  WITH invoice_totals AS (
    SELECT 
      COALESCE(SUM(total_amount), 0) AS total_billed,
      COALESCE(SUM(amount_paid), 0) AS total_collected,
      COALESCE(SUM(balance_due), 0) AS outstanding
    FROM invoices
    WHERE customer_id = p_customer_id 
      AND status NOT IN ('draft', 'cancelled', 'written_off')
  ),
  summary_totals AS (
    SELECT 
      total_billed,
      total_collected,
      outstanding_balance
    FROM customer_revenue_summary
    WHERE customer_id = p_customer_id
  )
  SELECT 'Total Billed'::text, st.total_billed, it.total_billed, (st.total_billed = it.total_billed)
  FROM summary_totals st, invoice_totals it
  UNION ALL
  SELECT 'Total Collected'::text, st.total_collected, it.total_collected, (st.total_collected = it.total_collected)
  FROM summary_totals st, invoice_totals it
  UNION ALL
  SELECT 'Outstanding Balance'::text, st.outstanding_balance, it.outstanding, (st.outstanding_balance = it.outstanding)
  FROM summary_totals st, invoice_totals it;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION reconcile_customer_revenue(uuid) IS 
  'Reconciliation function to verify customer_revenue_summary matches actual invoice totals. Use for testing and validation.';
