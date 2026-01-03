/*
  # Ticket-Invoice Integration - Part 3: Workflow Functions & Triggers

  ## Overview
  Creates functions and triggers to maintain data integrity and automate workflow.

  ## Changes
  1. Function to calculate ticket billed amount
  2. Function to validate ticket status transitions
  3. Triggers to sync billed amounts
  4. Triggers to enforce business rules
*/

-- =====================================================
-- 1. Function: Calculate ticket billed amount
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_ticket_billed_amount(p_ticket_id uuid)
RETURNS numeric AS $$
DECLARE
  v_total numeric;
BEGIN
  -- Sum from direct invoice link (1:1)
  SELECT COALESCE(SUM(i.total_amount), 0)
  INTO v_total
  FROM invoices i
  WHERE (i.ticket_id = p_ticket_id OR i.source_ticket_id = p_ticket_id)
    AND i.status NOT IN ('cancelled', 'written_off');

  -- Add from many-to-many links
  SELECT v_total + COALESCE(SUM(til.amount_contributed), 0)
  INTO v_total
  FROM ticket_invoice_links til
  JOIN invoices i ON i.id = til.invoice_id
  WHERE til.ticket_id = p_ticket_id
    AND i.status NOT IN ('cancelled', 'written_off');

  RETURN COALESCE(v_total, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION calculate_ticket_billed_amount IS 'Calculates total billed amount for a ticket across all linked invoices';

-- =====================================================
-- 2. Function: Validate ticket status transition
-- =====================================================

CREATE OR REPLACE FUNCTION validate_ticket_status_transition()
RETURNS TRIGGER AS $$
BEGIN
  -- Prevent moving away from closed_billed if invoice exists and is not draft
  IF OLD.status = 'closed_billed' AND NEW.status != 'closed_billed' THEN
    IF EXISTS (
      SELECT 1 FROM invoices 
      WHERE (ticket_id = NEW.id OR source_ticket_id = NEW.id)
        AND status NOT IN ('draft', 'cancelled', 'written_off')
    ) THEN
      RAISE EXCEPTION 'Cannot change status of billed ticket. Invoice must be voided first.';
    END IF;
  END IF;

  -- Require billable flag to be set when moving to ready_to_invoice
  IF NEW.status = 'ready_to_invoice' AND NEW.billable = false THEN
    RAISE EXCEPTION 'Cannot mark non-billable ticket as ready to invoice';
  END IF;

  -- Auto-set timestamps based on status
  IF NEW.status = 'ready_to_invoice' AND OLD.status != 'ready_to_invoice' THEN
    NEW.ready_to_invoice_at = now();
  END IF;

  IF NEW.status = 'closed_billed' AND OLD.status != 'closed_billed' THEN
    NEW.billed_at = now();
  END IF;

  -- If moving to closed_no_charge, ensure billable is false
  IF NEW.status = 'closed_no_charge' THEN
    NEW.billable = false;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_ticket_status_transition_trigger ON tickets;
CREATE TRIGGER validate_ticket_status_transition_trigger
  BEFORE UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION validate_ticket_status_transition();

COMMENT ON FUNCTION validate_ticket_status_transition IS 'Enforces business rules for ticket status changes and sets timestamps';

-- =====================================================
-- 3. Function: Sync ticket billed amount on invoice change
-- =====================================================

CREATE OR REPLACE FUNCTION sync_ticket_billed_amount()
RETURNS TRIGGER AS $$
DECLARE
  v_ticket_id uuid;
BEGIN
  -- Handle direct ticket link
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    IF NEW.ticket_id IS NOT NULL THEN
      UPDATE tickets 
      SET billed_amount = calculate_ticket_billed_amount(NEW.ticket_id)
      WHERE id = NEW.ticket_id;
    END IF;
    
    IF NEW.source_ticket_id IS NOT NULL THEN
      UPDATE tickets 
      SET billed_amount = calculate_ticket_billed_amount(NEW.source_ticket_id)
      WHERE id = NEW.source_ticket_id;
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    IF OLD.ticket_id IS NOT NULL THEN
      UPDATE tickets 
      SET billed_amount = calculate_ticket_billed_amount(OLD.ticket_id)
      WHERE id = OLD.ticket_id;
    END IF;
    
    IF OLD.source_ticket_id IS NOT NULL THEN
      UPDATE tickets 
      SET billed_amount = calculate_ticket_billed_amount(OLD.source_ticket_id)
      WHERE id = OLD.source_ticket_id;
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS sync_ticket_billed_amount_trigger ON invoices;
CREATE TRIGGER sync_ticket_billed_amount_trigger
  AFTER INSERT OR UPDATE OR DELETE ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION sync_ticket_billed_amount();

COMMENT ON FUNCTION sync_ticket_billed_amount IS 'Automatically updates ticket billed_amount when invoice changes';

-- =====================================================
-- 4. Function: Sync ticket billed amount on link change
-- =====================================================

CREATE OR REPLACE FUNCTION sync_ticket_billed_amount_on_link()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    UPDATE tickets 
    SET billed_amount = calculate_ticket_billed_amount(NEW.ticket_id)
    WHERE id = NEW.ticket_id;
  END IF;

  IF TG_OP = 'DELETE' THEN
    UPDATE tickets 
    SET billed_amount = calculate_ticket_billed_amount(OLD.ticket_id)
    WHERE id = OLD.ticket_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS sync_ticket_billed_amount_on_link_trigger ON ticket_invoice_links;
CREATE TRIGGER sync_ticket_billed_amount_on_link_trigger
  AFTER INSERT OR UPDATE OR DELETE ON ticket_invoice_links
  FOR EACH ROW
  EXECUTE FUNCTION sync_ticket_billed_amount_on_link();

COMMENT ON FUNCTION sync_ticket_billed_amount_on_link IS 'Updates ticket billed_amount when many-to-many links change';

-- =====================================================
-- 5. Function: Prevent invoice deletion with payments
-- =====================================================

CREATE OR REPLACE FUNCTION prevent_invoice_deletion_with_payments()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.amount_paid > 0 THEN
    RAISE EXCEPTION 'Cannot delete invoice with payments. Use credit/adjustment workflow instead.';
  END IF;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS prevent_invoice_deletion_trigger ON invoices;
CREATE TRIGGER prevent_invoice_deletion_trigger
  BEFORE DELETE ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION prevent_invoice_deletion_with_payments();

COMMENT ON FUNCTION prevent_invoice_deletion_with_payments IS 'Prevents deletion of invoices that have received payments';

-- =====================================================
-- 6. Function: Update invoice status based on payments
-- =====================================================

CREATE OR REPLACE FUNCTION update_invoice_status_on_payment()
RETURNS TRIGGER AS $$
BEGIN
  -- Auto-update status based on payment amount
  IF NEW.amount_paid >= NEW.total_amount THEN
    NEW.status = 'paid';
    NEW.paid_date = CURRENT_DATE;
  ELSIF NEW.amount_paid > 0 AND NEW.amount_paid < NEW.total_amount THEN
    NEW.status = 'partially_paid';
  ELSIF NEW.status = 'draft' AND NEW.amount_paid = 0 THEN
    -- Keep as draft
    NEW.status = 'draft';
  END IF;

  -- Update balance due
  NEW.balance_due = NEW.total_amount - NEW.amount_paid;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_invoice_status_trigger ON invoices;
CREATE TRIGGER update_invoice_status_trigger
  BEFORE INSERT OR UPDATE ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION update_invoice_status_on_payment();

COMMENT ON FUNCTION update_invoice_status_on_payment IS 'Automatically updates invoice status based on payment amount';

-- =====================================================
-- 7. Function: Auto-update ticket status when invoice created
-- =====================================================

CREATE OR REPLACE FUNCTION auto_update_ticket_on_invoice_creation()
RETURNS TRIGGER AS $$
BEGIN
  -- When invoice is created from a ready_to_invoice ticket, mark it billed
  IF TG_OP = 'INSERT' AND NEW.status != 'draft' THEN
    IF NEW.ticket_id IS NOT NULL THEN
      UPDATE tickets 
      SET status = 'closed_billed',
          billed_at = now()
      WHERE id = NEW.ticket_id 
        AND status = 'ready_to_invoice';
    END IF;
    
    IF NEW.source_ticket_id IS NOT NULL THEN
      UPDATE tickets 
      SET status = 'closed_billed',
          billed_at = now()
      WHERE id = NEW.source_ticket_id 
        AND status = 'ready_to_invoice';
    END IF;
  END IF;

  -- If invoice is cancelled/written off, revert ticket to ready_to_invoice
  IF TG_OP = 'UPDATE' AND NEW.status IN ('cancelled', 'written_off') AND OLD.status NOT IN ('cancelled', 'written_off') THEN
    IF NEW.ticket_id IS NOT NULL THEN
      UPDATE tickets 
      SET status = 'ready_to_invoice',
          billed_at = NULL
      WHERE id = NEW.ticket_id 
        AND status = 'closed_billed'
        AND NOT EXISTS (
          SELECT 1 FROM invoices i2 
          WHERE (i2.ticket_id = NEW.ticket_id OR i2.source_ticket_id = NEW.ticket_id)
            AND i2.id != NEW.id
            AND i2.status NOT IN ('cancelled', 'written_off')
        );
    END IF;
    
    IF NEW.source_ticket_id IS NOT NULL THEN
      UPDATE tickets 
      SET status = 'ready_to_invoice',
          billed_at = NULL
      WHERE id = NEW.source_ticket_id 
        AND status = 'closed_billed'
        AND NOT EXISTS (
          SELECT 1 FROM invoices i2 
          WHERE (i2.ticket_id = NEW.source_ticket_id OR i2.source_ticket_id = NEW.source_ticket_id)
            AND i2.id != NEW.id
            AND i2.status NOT IN ('cancelled', 'written_off')
        );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS auto_update_ticket_trigger ON invoices;
CREATE TRIGGER auto_update_ticket_trigger
  AFTER INSERT OR UPDATE ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION auto_update_ticket_on_invoice_creation();

COMMENT ON FUNCTION auto_update_ticket_on_invoice_creation IS 'Syncs ticket status with invoice lifecycle (creates, cancels)';
