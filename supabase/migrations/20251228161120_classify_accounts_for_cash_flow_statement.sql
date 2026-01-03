/*
  # Classify Accounts for Cash Flow Statement
  
  1. Purpose
    - Mark cash/bank accounts with is_cash_account = true
    - Set cash_flow_section overrides for key account types
    - Enable accurate Cash Flow Statement classification
    
  2. Cash Accounts Marked
    - Cash - Operating (1000)
    - Any other accounts with "Cash" or "Bank" in name and subtype = 'Cash'
    
  3. Cash Flow Section Classifications
    - Fixed Assets (Vehicles, Tools & Equipment, Buildings, etc.) → investing
    - Accumulated Depreciation → non_cash (depreciation doesn't affect cash)
    - Long-term Liabilities (Notes Payable, Loans) → financing
    - Owner's Equity accounts (Capital, Draws) → financing
    - Revenue accounts → operating (default, but explicit)
    - Expense accounts → operating (default, but explicit)
    - Current assets/liabilities (AR, AP, Inventory) → operating
    
  4. Notes
    - Most accounts leave cash_flow_section = NULL to use automatic classification
    - Only set explicit overrides where the classification is unambiguous
    - Operating is the default/fallback, so we don't need to set it everywhere
*/

-- Mark cash accounts
UPDATE chart_of_accounts
SET is_cash_account = true
WHERE account_code = '1000'  -- Cash - Operating
   OR (account_subtype = 'Cash' AND account_type = 'asset');

-- Set cash_flow_section for Fixed Assets → Investing
UPDATE chart_of_accounts
SET cash_flow_section = 'investing'
WHERE account_subtype IN ('Fixed Assets', 'Property, Plant & Equipment', 'Long-term Investments')
  AND account_type = 'asset';

-- Set cash_flow_section for Accumulated Depreciation → Non-cash
UPDATE chart_of_accounts
SET cash_flow_section = 'non_cash'
WHERE account_subtype = 'Contra Asset' 
   OR account_name ILIKE '%accumulated depreciation%'
   OR account_name ILIKE '%amortization%';

-- Set cash_flow_section for Long-term Liabilities → Financing
UPDATE chart_of_accounts
SET cash_flow_section = 'financing'
WHERE account_type = 'liability'
  AND (
    account_subtype IN ('Long-term Debt', 'Notes Payable', 'Loans Payable')
    OR account_name ILIKE '%loan%'
    OR account_name ILIKE '%note payable%'
    OR account_name ILIKE '%mortgage%'
  );

-- Set cash_flow_section for Equity accounts → Financing
UPDATE chart_of_accounts
SET cash_flow_section = 'financing'
WHERE account_type = 'equity'
  AND (
    account_name ILIKE '%owner%draw%'
    OR account_name ILIKE '%dividend%'
    OR account_name ILIKE '%distribution%'
    OR account_name ILIKE '%capital contribution%'
    OR account_name ILIKE '%owner%capital%'
  );

-- Current assets and liabilities default to Operating (NULL = auto-classify as operating)
-- Revenue and Expense accounts default to Operating (NULL = auto-classify as operating)

-- Summary report
DO $$
DECLARE
  cash_count INT;
  investing_count INT;
  financing_count INT;
  non_cash_count INT;
BEGIN
  SELECT COUNT(*) INTO cash_count FROM chart_of_accounts WHERE is_cash_account = true;
  SELECT COUNT(*) INTO investing_count FROM chart_of_accounts WHERE cash_flow_section = 'investing';
  SELECT COUNT(*) INTO financing_count FROM chart_of_accounts WHERE cash_flow_section = 'financing';
  SELECT COUNT(*) INTO non_cash_count FROM chart_of_accounts WHERE cash_flow_section = 'non_cash';
  
  RAISE NOTICE 'Cash Flow Classification Complete:';
  RAISE NOTICE '  Cash accounts marked: %', cash_count;
  RAISE NOTICE '  Investing accounts: %', investing_count;
  RAISE NOTICE '  Financing accounts: %', financing_count;
  RAISE NOTICE '  Non-cash accounts: %', non_cash_count;
END $$;
