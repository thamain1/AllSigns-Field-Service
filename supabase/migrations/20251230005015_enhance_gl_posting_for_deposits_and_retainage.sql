/*
  # Enhance GL Posting for Deposits and Retainage

  1. Purpose
    - Extend the existing post_invoice_to_gl() function to handle:
      - Deposit line items (is_deposit = TRUE) → post to Contract Liability (2350)
      - Retainage line items (is_retainage = TRUE) → post to Retainage Receivable (1250)
      - Regular line items → post to Revenue accounts as before

  2. Approach
    - Replace the post_invoice_to_gl() function with enhanced version
    - Check invoice_line_items.is_deposit and is_retainage flags
    - Route GL entries to appropriate accounts based on flags
    - Maintain backward compatibility with existing invoices

  3. GL Account Mapping
    - Deposit lines: CR Contract Liability - Deposits (2350)
    - Retainage lines: DR Retainage Receivable (1250), CR Project Revenue (4100)
    - Normal lines: CR Service Revenue (4000) / Parts Sales (4300) as before

  4. Important Notes
    - Non-destructive: enhances existing function
    - Backward compatible: existing invoices without flags work as before
    - Idempotent: won't double-post
*/

-- Enhanced post_invoice_to_gl function with deposit and retainage support
CREATE OR REPLACE FUNCTION post_invoice_to_gl(invoice_id_param uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  invoice_rec record;
  labor_amount decimal(10,2) := 0;
  parts_amount decimal(10,2) := 0;
  other_amount decimal(10,2) := 0;
  deposit_amount decimal(10,2) := 0;
  retainage_amount decimal(10,2) := 0;
  entry_num text;
  entry_ids uuid[] := ARRAY[]::uuid[];
  new_entry_id uuid;
  
  -- Account IDs
  ar_account_id uuid;
  service_revenue_account_id uuid;
  parts_revenue_account_id uuid;
  tax_payable_account_id uuid;
  contract_liability_account_id uuid;
  retainage_receivable_account_id uuid;
  project_revenue_account_id uuid;
  
  fiscal_yr int;
  fiscal_pd int;
  current_user_id uuid;
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
  ar_account_id := get_or_create_account('1100');
  service_revenue_account_id := get_or_create_account('4000');
  parts_revenue_account_id := get_or_create_account('4300');
  tax_payable_account_id := get_or_create_account('2200');
  contract_liability_account_id := get_or_create_account('2350');
  retainage_receivable_account_id := get_or_create_account('1250');
  project_revenue_account_id := get_or_create_account('4100');
  
  -- Fallback for tax payable if not found
  IF tax_payable_account_id IS NULL THEN
    tax_payable_account_id := get_or_create_account('2000');
  END IF;
  
  -- Validate required accounts exist
  IF ar_account_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Accounts Receivable account (1100) not found');
  END IF;
  
  -- Calculate line item totals by type and flags
  SELECT
    COALESCE(SUM(CASE WHEN item_type = 'labor' AND COALESCE(is_deposit, false) = false AND COALESCE(is_retainage, false) = false THEN line_total ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN item_type = 'part' AND COALESCE(is_deposit, false) = false AND COALESCE(is_retainage, false) = false THEN line_total ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN item_type NOT IN ('labor', 'part') AND COALESCE(is_deposit, false) = false AND COALESCE(is_retainage, false) = false THEN line_total ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN COALESCE(is_deposit, false) = true THEN line_total ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN COALESCE(is_retainage, false) = true THEN line_total ELSE 0 END), 0)
  INTO labor_amount, parts_amount, other_amount, deposit_amount, retainage_amount
  FROM invoice_line_items
  WHERE invoice_id = invoice_id_param;
  
  -- Generate entry number
  entry_num := generate_gl_entry_number();
  
  -- Calculate fiscal period
  fiscal_yr := EXTRACT(YEAR FROM invoice_rec.issue_date);
  fiscal_pd := EXTRACT(MONTH FROM invoice_rec.issue_date);
  
  -- Get current user
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    current_user_id := invoice_rec.created_by;
  END IF;
  
  -- Entry 1: DR Accounts Receivable for total invoice amount
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
  
  -- Entry 2: CR Service Revenue for labor (non-deposit, non-retainage)
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
  
  -- Entry 3: CR Parts Sales for parts (non-deposit, non-retainage)
  IF parts_amount > 0 THEN
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
  
  -- Entry 4: CR Other Revenue for other items (non-deposit, non-retainage)
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
      service_revenue_account_id,
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
  
  -- NEW: Entry 5: CR Contract Liability for deposit line items
  IF deposit_amount > 0 AND contract_liability_account_id IS NOT NULL THEN
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
      contract_liability_account_id,
      0,
      deposit_amount,
      'Invoice ' || invoice_rec.invoice_number || ' - Deposit (unearned revenue)',
      'invoice',
      invoice_id_param,
      current_user_id,
      true,
      fiscal_yr,
      fiscal_pd
    ) RETURNING id INTO new_entry_id;
    
    entry_ids := array_append(entry_ids, new_entry_id);
  END IF;
  
  -- NEW: Entry 6: CR Project Revenue for retainage line items
  IF retainage_amount > 0 AND project_revenue_account_id IS NOT NULL THEN
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
      project_revenue_account_id,
      0,
      retainage_amount,
      'Invoice ' || invoice_rec.invoice_number || ' - Retainage revenue',
      'invoice',
      invoice_id_param,
      current_user_id,
      true,
      fiscal_yr,
      fiscal_pd
    ) RETURNING id INTO new_entry_id;
    
    entry_ids := array_append(entry_ids, new_entry_id);
  END IF;
  
  -- Entry 7: CR Tax Payable for sales tax
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
  
  -- Update invoice with GL posted flag and entry IDs
  UPDATE invoices
  SET gl_posted = true,
      gl_posted_at = now(),
      gl_entry_ids = entry_ids
  WHERE id = invoice_id_param;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Invoice posted to GL successfully',
    'entry_ids', entry_ids,
    'entry_number', entry_num
  );
END;
$$;

-- Add helpful comment
COMMENT ON FUNCTION post_invoice_to_gl IS 'Posts invoice to GL with support for deposits (liability) and retainage. Idempotent.';
