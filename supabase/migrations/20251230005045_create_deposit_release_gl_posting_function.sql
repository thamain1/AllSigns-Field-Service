/*
  # Create GL Posting Function for Deposit Releases

  1. Purpose
    - Create function to post deposit releases to GL
    - Moves amount from Contract Liability (2350) to Project Revenue (4100)
    - Creates proper double-entry journal

  2. Function: post_deposit_release_to_gl
    - Takes project_deposit_release.id as parameter
    - Creates GL entry with:
      - DR Contract Liability - Deposits (2350)
      - CR Project Revenue (4100)
    - Updates deposit release record with GL info
    - Idempotent

  3. Important Notes
    - Non-destructive: new function only
    - Integrates with existing GL framework
*/

-- Function to post deposit release to GL
CREATE OR REPLACE FUNCTION post_deposit_release_to_gl(deposit_release_id_param uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  release_rec record;
  entry_num text;
  entry_ids uuid[] := ARRAY[]::uuid[];
  new_entry_id uuid;
  
  -- Account IDs
  contract_liability_account_id uuid;
  project_revenue_account_id uuid;
  
  fiscal_yr int;
  fiscal_pd int;
  current_user_id uuid;
BEGIN
  -- Get deposit release details
  SELECT * INTO release_rec
  FROM project_deposit_releases
  WHERE id = deposit_release_id_param;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Deposit release not found');
  END IF;
  
  -- Check if already posted
  IF release_rec.gl_posted THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Deposit release already posted to GL',
      'gl_entry_id', release_rec.gl_entry_id
    );
  END IF;
  
  -- Get account IDs
  contract_liability_account_id := get_or_create_account('2350');
  project_revenue_account_id := get_or_create_account('4100');
  
  -- Validate required accounts exist
  IF contract_liability_account_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Contract Liability account (2350) not found');
  END IF;
  
  IF project_revenue_account_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Project Revenue account (4100) not found');
  END IF;
  
  -- Generate entry number
  entry_num := generate_gl_entry_number();
  
  -- Calculate fiscal period
  fiscal_yr := EXTRACT(YEAR FROM release_rec.release_date);
  fiscal_pd := EXTRACT(MONTH FROM release_rec.release_date);
  
  -- Get current user
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    current_user_id := release_rec.created_by;
  END IF;
  
  -- Entry 1: DR Contract Liability - Deposits (reduce liability)
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
    release_rec.release_date,
    contract_liability_account_id,
    release_rec.release_amount,
    0,
    'Deposit release - ' || COALESCE(release_rec.release_reason, 'Work performed'),
    'deposit_release',
    deposit_release_id_param,
    current_user_id,
    true,
    fiscal_yr,
    fiscal_pd
  ) RETURNING id INTO new_entry_id;
  
  entry_ids := array_append(entry_ids, new_entry_id);
  
  -- Entry 2: CR Project Revenue (recognize revenue)
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
    release_rec.release_date,
    project_revenue_account_id,
    0,
    release_rec.release_amount,
    'Deposit release - ' || COALESCE(release_rec.release_reason, 'Work performed'),
    'deposit_release',
    deposit_release_id_param,
    current_user_id,
    true,
    fiscal_yr,
    fiscal_pd
  ) RETURNING id INTO new_entry_id;
  
  entry_ids := array_append(entry_ids, new_entry_id);
  
  -- Update deposit release record with GL info
  UPDATE project_deposit_releases
  SET gl_posted = true,
      gl_posted_at = now(),
      gl_entry_id = entry_ids[1]
  WHERE id = deposit_release_id_param;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Deposit release posted to GL successfully',
    'entry_ids', entry_ids,
    'entry_number', entry_num
  );
END;
$$;

-- Add helpful comment
COMMENT ON FUNCTION post_deposit_release_to_gl IS 'Posts deposit release from liability to revenue. DR Contract Liability (2350), CR Project Revenue (4100). Idempotent.';

-- Create trigger to auto-post deposit releases to GL
CREATE OR REPLACE FUNCTION auto_post_deposit_release_to_gl()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Auto-post to GL when deposit release is created
  PERFORM post_deposit_release_to_gl(NEW.id);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_auto_post_deposit_release
AFTER INSERT ON project_deposit_releases
FOR EACH ROW
EXECUTE FUNCTION auto_post_deposit_release_to_gl();

COMMENT ON TRIGGER trigger_auto_post_deposit_release ON project_deposit_releases IS 'Automatically posts deposit releases to GL when created';
