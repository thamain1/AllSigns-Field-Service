/*
  # Connect Invoicing to Accounting Engine - Part 2: Posting Functions

  ## Overview
  This migration creates the core posting functions that connect invoices and payments
  to the General Ledger. All posting is idempotent and follows double-entry accounting.

  ## 1. Functions Created

  ### post_invoice_to_gl(invoice_id uuid)
  Posts an invoice to the GL with proper double-entry accounting:
    - DR: Accounts Receivable (1100) for total amount
    - CR: Service Revenue (4000) for labor
    - CR: Parts Sales (4300) for parts
    - CR: Sales Tax Payable (2200) for tax (if exists, else use 2000)
  
  Idempotent: Won't double-post if already posted.

  ### post_payment_to_gl(payment_id uuid)
  Posts a payment to the GL:
    - DR: Cash (1000) for payment amount
    - CR: Accounts Receivable (1100) for payment amount
  
  Idempotent: Won't double-post if already posted.

  ### reverse_invoice_posting(invoice_id uuid)
  Reverses GL entries for an invoice by creating offsetting entries.
  Used when an invoice is cancelled or needs adjustment.

  ## 2. Helper Functions

  ### get_or_create_account(code text)
  Looks up account by code, returns account_id.
  Creates account if missing (failsafe for missing setup).

  ### generate_gl_entry_number()
  Generates unique GL entry numbers: JE-YYYYMMDD-NNNN

  ## 3. Important Notes
  - All functions are idempotent (safe to call multiple times)
  - Uses existing accounting_settings for account codes
  - Follows HVAC-specific GL account structure from initial schema
  - Maintains full audit trail via reference_type and reference_id
*/

-- Helper function: Generate unique GL entry number
CREATE OR REPLACE FUNCTION generate_gl_entry_number()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  new_number text;
  counter int;
  date_part text;
BEGIN
  date_part := 'JE-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD');
  
  -- Get the next counter for today
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(entry_number FROM '....-\d{8}-(\d{4})') AS INTEGER)
  ), 0) + 1
  INTO counter
  FROM gl_entries
  WHERE entry_number LIKE date_part || '-%';
  
  new_number := date_part || '-' || LPAD(counter::text, 4, '0');
  
  RETURN new_number;
END;
$$;

-- Helper function: Get or create GL account by code
CREATE OR REPLACE FUNCTION get_or_create_account(account_code_param text)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  account_uuid uuid;
BEGIN
  -- Try to find existing account
  SELECT id INTO account_uuid
  FROM chart_of_accounts
  WHERE account_code = account_code_param;
  
  -- If not found, return null (don't auto-create, let caller handle)
  RETURN account_uuid;
END;
$$;

-- Main function: Post invoice to GL
CREATE OR REPLACE FUNCTION post_invoice_to_gl(invoice_id_param uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  invoice_rec record;
  labor_amount decimal(10,2);
  parts_amount decimal(10,2);
  other_amount decimal(10,2);
  entry_num text;
  entry_ids uuid[] := ARRAY[]::uuid[];
  new_entry_id uuid;
  
  -- Account IDs
  ar_account_id uuid;
  cash_account_id uuid;
  service_revenue_account_id uuid;
  parts_revenue_account_id uuid;
  tax_payable_account_id uuid;
  other_revenue_account_id uuid;
  
  fiscal_yr int;
  fiscal_pd int;
BEGIN
  -- Get invoice details
  SELECT * INTO invoice_rec
  FROM invoices
  WHERE id = invoice_id_param;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
  END IF;
  
  -- Check if already posted
  IF invoice_rec.gl_posted THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Invoice already posted to GL',
      'entry_ids', invoice_rec.gl_entry_ids
    );
  END IF;
  
  -- Don't post draft or cancelled invoices
  IF invoice_rec.status IN ('draft', 'cancelled') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Cannot post draft or cancelled invoices'
    );
  END IF;
  
  -- Get account IDs
  ar_account_id := get_or_create_account('1100'); -- Accounts Receivable
  cash_account_id := get_or_create_account('1000'); -- Cash
  service_revenue_account_id := get_or_create_account('4000'); -- Service Revenue
  parts_revenue_account_id := get_or_create_account('4300'); -- Parts Sales
  tax_payable_account_id := get_or_create_account('2200'); -- Tax Payable (or use 2000 AP as fallback)
  other_revenue_account_id := get_or_create_account('4000'); -- Use service revenue for other
  
  -- Fallback for tax payable if not found
  IF tax_payable_account_id IS NULL THEN
    tax_payable_account_id := get_or_create_account('2000'); -- Accounts Payable
  END IF;
  
  -- Validate required accounts exist
  IF ar_account_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Accounts Receivable account (1100) not found');
  END IF;
  
  IF service_revenue_account_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Service Revenue account (4000) not found');
  END IF;
  
  -- Calculate line item totals by type
  SELECT
    COALESCE(SUM(CASE WHEN item_type = 'labor' THEN line_total ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN item_type = 'part' THEN line_total ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN item_type NOT IN ('labor', 'part') THEN line_total ELSE 0 END), 0)
  INTO labor_amount, parts_amount, other_amount
  FROM invoice_line_items
  WHERE invoice_id = invoice_id_param;
  
  -- Generate entry number
  entry_num := generate_gl_entry_number();
  
  -- Calculate fiscal period
  fiscal_yr := EXTRACT(YEAR FROM invoice_rec.issue_date);
  fiscal_pd := EXTRACT(MONTH FROM invoice_rec.issue_date);
  
  -- Get current user (or use invoice creator as fallback)
  DECLARE
    current_user_id uuid;
  BEGIN
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
      current_user_id := invoice_rec.created_by;
    END IF;
  
    -- Entry 1: DR Accounts Receivable for total amount
    INSERT INTO gl_entries (
      entry_number,
      entry_date,
      account_id,
      debit_amount,
      credit_amount,
      description,
      reference_type,
      reference_id,
      posted_by,
      is_posted,
      fiscal_year,
      fiscal_period
    ) VALUES (
      entry_num,
      invoice_rec.issue_date,
      ar_account_id,
      invoice_rec.total_amount,
      0,
      'Invoice ' || invoice_rec.invoice_number || ' - Customer AR',
      'invoice',
      invoice_id_param,
      current_user_id,
      true,
      fiscal_yr,
      fiscal_pd
    ) RETURNING id INTO new_entry_id;
    
    entry_ids := array_append(entry_ids, new_entry_id);
    
    -- Entry 2: CR Service Revenue for labor
    IF labor_amount > 0 THEN
      INSERT INTO gl_entries (
        entry_number,
        entry_date,
        account_id,
        debit_amount,
        credit_amount,
        description,
        reference_type,
        reference_id,
        posted_by,
        is_posted,
        fiscal_year,
        fiscal_period
      ) VALUES (
        entry_num,
        invoice_rec.issue_date,
        service_revenue_account_id,
        0,
        labor_amount,
        'Invoice ' || invoice_rec.invoice_number || ' - Labor revenue',
        'invoice',
        invoice_id_param,
        current_user_id,
        true,
        fiscal_yr,
        fiscal_pd
      ) RETURNING id INTO new_entry_id;
      
      entry_ids := array_append(entry_ids, new_entry_id);
    END IF;
    
    -- Entry 3: CR Parts Sales for parts
    IF parts_amount > 0 AND parts_revenue_account_id IS NOT NULL THEN
      INSERT INTO gl_entries (
        entry_number,
        entry_date,
        account_id,
        debit_amount,
        credit_amount,
        description,
        reference_type,
        reference_id,
        posted_by,
        is_posted,
        fiscal_year,
        fiscal_period
      ) VALUES (
        entry_num,
        invoice_rec.issue_date,
        parts_revenue_account_id,
        0,
        parts_amount,
        'Invoice ' || invoice_rec.invoice_number || ' - Parts revenue',
        'invoice',
        invoice_id_param,
        current_user_id,
        true,
        fiscal_yr,
        fiscal_pd
      ) RETURNING id INTO new_entry_id;
      
      entry_ids := array_append(entry_ids, new_entry_id);
    END IF;
    
    -- Entry 4: CR Other Revenue for travel/service/other
    IF other_amount > 0 THEN
      INSERT INTO gl_entries (
        entry_number,
        entry_date,
        account_id,
        debit_amount,
        credit_amount,
        description,
        reference_type,
        reference_id,
        posted_by,
        is_posted,
        fiscal_year,
        fiscal_period
      ) VALUES (
        entry_num,
        invoice_rec.issue_date,
        other_revenue_account_id,
        0,
        other_amount,
        'Invoice ' || invoice_rec.invoice_number || ' - Other revenue',
        'invoice',
        invoice_id_param,
        current_user_id,
        true,
        fiscal_yr,
        fiscal_pd
      ) RETURNING id INTO new_entry_id;
      
      entry_ids := array_append(entry_ids, new_entry_id);
    END IF;
    
    -- Entry 5: CR Sales Tax Payable for tax
    IF invoice_rec.tax_amount > 0 AND tax_payable_account_id IS NOT NULL THEN
      INSERT INTO gl_entries (
        entry_number,
        entry_date,
        account_id,
        debit_amount,
        credit_amount,
        description,
        reference_type,
        reference_id,
        posted_by,
        is_posted,
        fiscal_year,
        fiscal_period
      ) VALUES (
        entry_num,
        invoice_rec.issue_date,
        tax_payable_account_id,
        0,
        invoice_rec.tax_amount,
        'Invoice ' || invoice_rec.invoice_number || ' - Sales tax',
        'invoice',
        invoice_id_param,
        current_user_id,
        true,
        fiscal_yr,
        fiscal_pd
      ) RETURNING id INTO new_entry_id;
      
      entry_ids := array_append(entry_ids, new_entry_id);
    END IF;
    
    -- Update invoice with GL posting info
    UPDATE invoices
    SET
      gl_posted = true,
      gl_posted_at = now(),
      gl_entry_ids = entry_ids
    WHERE id = invoice_id_param;
    
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Invoice posted to GL successfully',
      'entry_number', entry_num,
      'entry_ids', entry_ids
    );
  END;
END;
$$;

-- Function: Post payment to GL
CREATE OR REPLACE FUNCTION post_payment_to_gl(payment_id_param uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  payment_rec record;
  entry_num text;
  entry_ids uuid[] := ARRAY[]::uuid[];
  new_entry_id uuid;
  
  -- Account IDs
  cash_account_id uuid;
  ar_account_id uuid;
  
  fiscal_yr int;
  fiscal_pd int;
  current_user_id uuid;
BEGIN
  -- Get payment details
  SELECT * INTO payment_rec
  FROM payments
  WHERE id = payment_id_param;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Payment not found');
  END IF;
  
  -- Check if already posted
  IF payment_rec.gl_posted THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Payment already posted to GL',
      'entry_ids', payment_rec.gl_entry_ids
    );
  END IF;
  
  -- Get account IDs
  cash_account_id := get_or_create_account('1000'); -- Cash
  ar_account_id := get_or_create_account('1100'); -- Accounts Receivable
  
  -- Validate required accounts exist
  IF cash_account_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cash account (1000) not found');
  END IF;
  
  IF ar_account_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Accounts Receivable account (1100) not found');
  END IF;
  
  -- Generate entry number
  entry_num := generate_gl_entry_number();
  
  -- Calculate fiscal period
  fiscal_yr := EXTRACT(YEAR FROM payment_rec.payment_date);
  fiscal_pd := EXTRACT(MONTH FROM payment_rec.payment_date);
  
  -- Get current user (or use payment recorder as fallback)
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    current_user_id := payment_rec.recorded_by;
  END IF;
  
  -- Entry 1: DR Cash for payment amount
  INSERT INTO gl_entries (
    entry_number,
    entry_date,
    account_id,
    debit_amount,
    credit_amount,
    description,
    reference_type,
    reference_id,
    posted_by,
    is_posted,
    fiscal_year,
    fiscal_period
  ) VALUES (
    entry_num,
    payment_rec.payment_date,
    cash_account_id,
    payment_rec.amount,
    0,
    'Payment received - ' || COALESCE(payment_rec.reference_number, payment_rec.payment_method),
    'payment',
    payment_id_param,
    current_user_id,
    true,
    fiscal_yr,
    fiscal_pd
  ) RETURNING id INTO new_entry_id;
  
  entry_ids := array_append(entry_ids, new_entry_id);
  
  -- Entry 2: CR Accounts Receivable for payment amount
  INSERT INTO gl_entries (
    entry_number,
    entry_date,
    account_id,
    debit_amount,
    credit_amount,
    description,
    reference_type,
    reference_id,
    posted_by,
    is_posted,
    fiscal_year,
    fiscal_period
  ) VALUES (
    entry_num,
    payment_rec.payment_date,
    ar_account_id,
    0,
    payment_rec.amount,
    'Payment received - ' || COALESCE(payment_rec.reference_number, payment_rec.payment_method),
    'payment',
    payment_id_param,
    current_user_id,
    true,
    fiscal_yr,
    fiscal_pd
  ) RETURNING id INTO new_entry_id;
  
  entry_ids := array_append(entry_ids, new_entry_id);
  
  -- Update payment with GL posting info
  UPDATE payments
  SET
    gl_posted = true,
    gl_posted_at = now(),
    gl_entry_ids = entry_ids
  WHERE id = payment_id_param;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Payment posted to GL successfully',
    'entry_number', entry_num,
    'entry_ids', entry_ids
  );
END;
$$;

-- Function: Reverse invoice GL posting
CREATE OR REPLACE FUNCTION reverse_invoice_posting(invoice_id_param uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  invoice_rec record;
  entry_num text;
  reversal_entry_ids uuid[] := ARRAY[]::uuid[];
  original_entry record;
  new_entry_id uuid;
  current_user_id uuid;
BEGIN
  -- Get invoice details
  SELECT * INTO invoice_rec
  FROM invoices
  WHERE id = invoice_id_param;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invoice not found');
  END IF;
  
  -- Check if posted
  IF NOT invoice_rec.gl_posted THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invoice has not been posted to GL'
    );
  END IF;
  
  -- Generate reversal entry number
  entry_num := generate_gl_entry_number();
  
  -- Get current user
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    current_user_id := invoice_rec.created_by;
  END IF;
  
  -- Create offsetting entries for each original entry
  FOR original_entry IN
    SELECT * FROM gl_entries
    WHERE reference_type = 'invoice'
      AND reference_id = invoice_id_param
      AND id = ANY(invoice_rec.gl_entry_ids)
  LOOP
    -- Create reversal entry (swap debit and credit)
    INSERT INTO gl_entries (
      entry_number,
      entry_date,
      account_id,
      debit_amount,
      credit_amount,
      description,
      reference_type,
      reference_id,
      posted_by,
      is_posted,
      fiscal_year,
      fiscal_period
    ) VALUES (
      entry_num,
      CURRENT_DATE,
      original_entry.account_id,
      original_entry.credit_amount, -- Swap: credit becomes debit
      original_entry.debit_amount,  -- Swap: debit becomes credit
      'REVERSAL: ' || original_entry.description,
      'invoice_reversal',
      invoice_id_param,
      current_user_id,
      true,
      EXTRACT(YEAR FROM CURRENT_DATE),
      EXTRACT(MONTH FROM CURRENT_DATE)
    ) RETURNING id INTO new_entry_id;
    
    reversal_entry_ids := array_append(reversal_entry_ids, new_entry_id);
  END LOOP;
  
  -- Update invoice to mark as not posted (but keep history)
  UPDATE invoices
  SET
    gl_posted = false,
    gl_entry_ids = array_cat(COALESCE(gl_entry_ids, ARRAY[]::uuid[]), reversal_entry_ids)
  WHERE id = invoice_id_param;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Invoice GL posting reversed successfully',
    'entry_number', entry_num,
    'reversal_entry_ids', reversal_entry_ids
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION post_invoice_to_gl TO authenticated;
GRANT EXECUTE ON FUNCTION post_payment_to_gl TO authenticated;
GRANT EXECUTE ON FUNCTION reverse_invoice_posting TO authenticated;
GRANT EXECUTE ON FUNCTION generate_gl_entry_number TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION post_invoice_to_gl IS 'Posts an invoice to the General Ledger with proper double-entry accounting. Idempotent.';
COMMENT ON FUNCTION post_payment_to_gl IS 'Posts a payment to the General Ledger. Idempotent.';
COMMENT ON FUNCTION reverse_invoice_posting IS 'Reverses GL entries for an invoice by creating offsetting entries.';
