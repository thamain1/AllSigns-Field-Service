/*
  # Connect Invoicing to Accounting Engine - Part 3: Triggers and Backfill

  ## Overview
  This migration adds automatic triggers to post invoices and payments to GL,
  plus a comprehensive backfill function to process existing records.

  ## 1. Triggers Created

  ### auto_post_invoice_to_gl
  Automatically posts invoice to GL when:
    - Status changes FROM 'draft' TO 'sent' (or any non-draft/cancelled status)
    - Invoice is updated to non-draft status
  
  Does NOT auto-post for draft or cancelled invoices.

  ### auto_post_payment_to_gl
  Automatically posts payment to GL when:
    - New payment record is inserted
  
  All payments are immediately posted to GL.

  ## 2. Backfill Function

  ### backfill_invoice_gl_entries(dry_run boolean DEFAULT true)
  Processes all existing invoices that should be posted to GL but aren't yet.
  
  Features:
    - Dry run mode by default (shows what would be done without making changes)
    - Idempotent (safe to run multiple times)
    - Processes only non-draft, non-cancelled, unposted invoices
    - Returns detailed report of what was processed
    - Includes all associated payments

  ## 3. Important Notes
  - Triggers only fire on NEW changes, not existing data
  - Use backfill function to process existing invoices
  - All operations are idempotent and safe
  - Full audit trail maintained
*/

-- Trigger function: Auto-post invoice to GL on status change
CREATE OR REPLACE FUNCTION trigger_auto_post_invoice_to_gl()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  -- Only auto-post when status changes from draft to a posted status
  -- or when a new invoice is created in a posted status
  IF (TG_OP = 'INSERT' AND NEW.status NOT IN ('draft', 'cancelled')) OR
     (TG_OP = 'UPDATE' AND 
      OLD.status = 'draft' AND 
      NEW.status NOT IN ('draft', 'cancelled') AND
      NEW.gl_posted = false) THEN
    
    -- Call the posting function
    SELECT post_invoice_to_gl(NEW.id) INTO result;
    
    -- Log any errors (but don't block the operation)
    IF NOT (result->>'success')::boolean THEN
      RAISE WARNING 'Failed to auto-post invoice % to GL: %', NEW.invoice_number, result->>'error';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for invoice posting
DROP TRIGGER IF EXISTS auto_post_invoice_to_gl_trigger ON invoices;
CREATE TRIGGER auto_post_invoice_to_gl_trigger
  AFTER INSERT OR UPDATE OF status ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION trigger_auto_post_invoice_to_gl();

-- Trigger function: Auto-post payment to GL on insert
CREATE OR REPLACE FUNCTION trigger_auto_post_payment_to_gl()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  -- Auto-post all new payments
  IF TG_OP = 'INSERT' AND NEW.gl_posted = false THEN
    -- Call the posting function
    SELECT post_payment_to_gl(NEW.id) INTO result;
    
    -- Log any errors (but don't block the operation)
    IF NOT (result->>'success')::boolean THEN
      RAISE WARNING 'Failed to auto-post payment to GL: %', result->>'error';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for payment posting
DROP TRIGGER IF EXISTS auto_post_payment_to_gl_trigger ON payments;
CREATE TRIGGER auto_post_payment_to_gl_trigger
  AFTER INSERT ON payments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_auto_post_payment_to_gl();

-- Backfill function: Process existing invoices and payments
CREATE OR REPLACE FUNCTION backfill_invoice_gl_entries(dry_run boolean DEFAULT true)
RETURNS TABLE (
  record_type text,
  record_id uuid,
  record_number text,
  status text,
  posted_result jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  invoice_rec record;
  payment_rec record;
  post_result jsonb;
  total_invoices int := 0;
  total_payments int := 0;
  success_count int := 0;
  error_count int := 0;
BEGIN
  -- Process unposted invoices (non-draft, non-cancelled)
  FOR invoice_rec IN
    SELECT
      i.id,
      i.invoice_number,
      i.status,
      i.gl_posted
    FROM invoices i
    WHERE i.gl_posted = false
      AND i.status NOT IN ('draft', 'cancelled')
    ORDER BY i.issue_date, i.invoice_number
  LOOP
    total_invoices := total_invoices + 1;
    
    IF dry_run THEN
      -- Dry run: just report what would be done
      record_type := 'invoice';
      record_id := invoice_rec.id;
      record_number := invoice_rec.invoice_number;
      status := 'would_post';
      posted_result := jsonb_build_object(
        'dry_run', true,
        'invoice_status', invoice_rec.status
      );
      RETURN NEXT;
    ELSE
      -- Actually post the invoice
      SELECT post_invoice_to_gl(invoice_rec.id) INTO post_result;
      
      IF (post_result->>'success')::boolean THEN
        success_count := success_count + 1;
      ELSE
        error_count := error_count + 1;
      END IF;
      
      record_type := 'invoice';
      record_id := invoice_rec.id;
      record_number := invoice_rec.invoice_number;
      status := CASE
        WHEN (post_result->>'success')::boolean THEN 'posted'
        ELSE 'error'
      END;
      posted_result := post_result;
      RETURN NEXT;
    END IF;
  END LOOP;
  
  -- Process unposted payments
  FOR payment_rec IN
    SELECT
      p.id,
      p.reference_number,
      p.payment_method,
      p.gl_posted,
      i.invoice_number
    FROM payments p
    JOIN invoices i ON p.invoice_id = i.id
    WHERE p.gl_posted = false
    ORDER BY p.payment_date
  LOOP
    total_payments := total_payments + 1;
    
    IF dry_run THEN
      -- Dry run: just report what would be done
      record_type := 'payment';
      record_id := payment_rec.id;
      record_number := COALESCE(payment_rec.reference_number, 'Payment-' || payment_rec.payment_method);
      status := 'would_post';
      posted_result := jsonb_build_object(
        'dry_run', true,
        'invoice_number', payment_rec.invoice_number
      );
      RETURN NEXT;
    ELSE
      -- Actually post the payment
      SELECT post_payment_to_gl(payment_rec.id) INTO post_result;
      
      IF (post_result->>'success')::boolean THEN
        success_count := success_count + 1;
      ELSE
        error_count := error_count + 1;
      END IF;
      
      record_type := 'payment';
      record_id := payment_rec.id;
      record_number := COALESCE(payment_rec.reference_number, 'Payment-' || payment_rec.payment_method);
      status := CASE
        WHEN (post_result->>'success')::boolean THEN 'posted'
        ELSE 'error'
      END;
      posted_result := post_result;
      RETURN NEXT;
    END IF;
  END LOOP;
  
  -- Return summary row
  record_type := 'summary';
  record_id := NULL;
  record_number := NULL;
  status := CASE WHEN dry_run THEN 'dry_run_complete' ELSE 'backfill_complete' END;
  posted_result := jsonb_build_object(
    'dry_run', dry_run,
    'total_invoices', total_invoices,
    'total_payments', total_payments,
    'success_count', success_count,
    'error_count', error_count
  );
  RETURN NEXT;
  
  RETURN;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION backfill_invoice_gl_entries TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION trigger_auto_post_invoice_to_gl IS 'Automatically posts invoice to GL when status changes from draft to posted state';
COMMENT ON FUNCTION trigger_auto_post_payment_to_gl IS 'Automatically posts payment to GL when payment record is inserted';
COMMENT ON FUNCTION backfill_invoice_gl_entries IS 'Backfills GL entries for existing invoices and payments. Use dry_run=true to preview changes.';

-- Add Sales Tax Payable account if it doesn't exist (for tax posting)
INSERT INTO chart_of_accounts (account_code, account_name, account_type, account_subtype, normal_balance, description)
VALUES ('2200', 'Sales Tax Payable', 'liability', 'Sales Tax', 'credit', 'Sales tax collected and owed to tax authorities')
ON CONFLICT (account_code) DO NOTHING;
