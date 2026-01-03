/*
  # Create Cancel Reconciliation Function
  
  1. Purpose
    - Provide a safe, transactional cancel operation for in-progress reconciliations
    - Ensures all steps complete successfully or roll back entirely
    - Prevents partial state if any operation fails
    
  2. Function: cancel_bank_reconciliation
    - Input: p_reconciliation_id (uuid), p_user_id (uuid)
    - Returns: Updated bank_reconciliation record
    - Steps performed in single transaction:
      a) Validate reconciliation exists and is in_progress
      b) Unmark all cleared GL entries (set reconciliation_id, cleared_at, cleared_by_user_id to NULL)
      c) Delete all bank statement lines for this reconciliation
      d) Update reconciliation status to 'cancelled', set cancelled_at and cancelled_by
    
  3. Safety
    - Transaction ensures atomicity (all-or-nothing)
    - Validates status before proceeding
    - Does not delete GL entries (only unlinks them)
    - Does not delete reconciliation record (only marks as cancelled)
    - Returns clear error messages for validation failures
    
  4. Usage
    SELECT * FROM cancel_bank_reconciliation('reconciliation-uuid', 'user-uuid');
*/

CREATE OR REPLACE FUNCTION cancel_bank_reconciliation(
  p_reconciliation_id uuid,
  p_user_id uuid
)
RETURNS bank_reconciliations
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_reconciliation bank_reconciliations;
  v_cleared_count int;
  v_lines_count int;
BEGIN
  -- Get and validate reconciliation
  SELECT * INTO v_reconciliation
  FROM bank_reconciliations
  WHERE id = p_reconciliation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reconciliation not found: %', p_reconciliation_id;
  END IF;
  
  -- Only in_progress reconciliations can be cancelled
  IF v_reconciliation.status != 'in_progress' THEN
    RAISE EXCEPTION 'Cannot cancel reconciliation with status: %. Only in_progress reconciliations can be cancelled.', v_reconciliation.status;
  END IF;
  
  -- Step 1: Unmark all cleared GL entries
  -- Set reconciliation_id, cleared_at, cleared_by_user_id to NULL
  UPDATE gl_entries
  SET 
    reconciliation_id = NULL,
    cleared_at = NULL,
    cleared_by_user_id = NULL
  WHERE reconciliation_id = p_reconciliation_id;
  
  GET DIAGNOSTICS v_cleared_count = ROW_COUNT;
  
  RAISE NOTICE 'Unmarked % GL entries', v_cleared_count;
  
  -- Step 2: Delete all bank statement lines for this reconciliation
  -- These are temporary lines imported for this specific reconciliation
  DELETE FROM bank_statement_lines
  WHERE reconciliation_id = p_reconciliation_id;
  
  GET DIAGNOSTICS v_lines_count = ROW_COUNT;
  
  RAISE NOTICE 'Deleted % bank statement lines', v_lines_count;
  
  -- Step 3: Update reconciliation status to cancelled
  UPDATE bank_reconciliations
  SET 
    status = 'cancelled',
    cancelled_at = NOW(),
    cancelled_by = p_user_id,
    cleared_balance = 0,
    difference = statement_ending_balance - 0
  WHERE id = p_reconciliation_id
  RETURNING * INTO v_reconciliation;
  
  RAISE NOTICE 'Reconciliation % cancelled successfully', p_reconciliation_id;
  
  -- Return updated reconciliation
  RETURN v_reconciliation;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Log error and re-raise
    RAISE EXCEPTION 'Failed to cancel reconciliation: %', SQLERRM;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION cancel_bank_reconciliation(uuid, uuid) TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION cancel_bank_reconciliation IS 
  'Safely cancels an in-progress bank reconciliation by unmarking GL entries, deleting statement lines, and updating status. All operations are performed in a single transaction.';
