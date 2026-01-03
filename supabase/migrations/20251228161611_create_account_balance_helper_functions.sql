/*
  # Create Account Balance Helper Functions
  
  1. Purpose
    - Provide helper functions to calculate account balances as of specific dates
    - Support Cash Flow Statement and Bank Reconciliation calculations
    - Enable consistent balance calculations across the application
    
  2. Functions Created
    - get_account_balance(account_id, as_of_date)
      Returns the balance of a single account as of a specific date
    - get_account_balances(as_of_date)
      Returns balances of all accounts as of a specific date
    
  3. Calculation Method
    - Sum all GL entries for the account up to and including the as_of_date
    - For debit-normal accounts: balance = sum(debits) - sum(credits)
    - For credit-normal accounts: balance = sum(credits) - sum(debits)
    
  4. Safety
    - Read-only functions (no data modification)
    - Efficient indexed queries
    - Handles NULL dates gracefully
*/

-- Function to get balance for a single account as of a specific date
CREATE OR REPLACE FUNCTION get_account_balance(
  p_account_id uuid,
  p_as_of_date date
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_normal_balance text;
  v_total_debits numeric;
  v_total_credits numeric;
  v_balance numeric;
BEGIN
  -- Get the normal balance type for this account
  SELECT normal_balance INTO v_normal_balance
  FROM chart_of_accounts
  WHERE id = p_account_id;
  
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  
  -- Sum debits and credits for this account up to the date
  SELECT 
    COALESCE(SUM(debit_amount), 0),
    COALESCE(SUM(credit_amount), 0)
  INTO v_total_debits, v_total_credits
  FROM gl_entries
  WHERE account_id = p_account_id
  AND entry_date <= p_as_of_date;
  
  -- Calculate balance based on normal balance type
  IF v_normal_balance = 'debit' THEN
    v_balance := v_total_debits - v_total_credits;
  ELSE
    v_balance := v_total_credits - v_total_debits;
  END IF;
  
  RETURN v_balance;
END;
$$;

-- Function to get balances for all accounts as of a specific date
CREATE OR REPLACE FUNCTION get_account_balances(
  p_as_of_date date
)
RETURNS TABLE (
  account_id uuid,
  account_code text,
  account_name text,
  account_type text,
  normal_balance text,
  balance numeric
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  WITH account_totals AS (
    SELECT 
      ge.account_id,
      SUM(ge.debit_amount) as total_debits,
      SUM(ge.credit_amount) as total_credits
    FROM gl_entries ge
    WHERE ge.entry_date <= p_as_of_date
    GROUP BY ge.account_id
  )
  SELECT 
    coa.id as account_id,
    coa.account_code,
    coa.account_name,
    coa.account_type::text,
    coa.normal_balance::text,
    CASE 
      WHEN coa.normal_balance = 'debit' THEN 
        COALESCE(at.total_debits, 0) - COALESCE(at.total_credits, 0)
      ELSE 
        COALESCE(at.total_credits, 0) - COALESCE(at.total_debits, 0)
    END as balance
  FROM chart_of_accounts coa
  LEFT JOIN account_totals at ON coa.id = at.account_id
  WHERE coa.is_active = true
  ORDER BY coa.account_code;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_account_balance(uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION get_account_balances(date) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION get_account_balance IS 
  'Returns the balance of a single account as of a specific date. Calculates based on normal balance type (debit or credit).';

COMMENT ON FUNCTION get_account_balances IS 
  'Returns balances for all active accounts as of a specific date. Used for financial statement generation.';
