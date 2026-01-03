/*
  # Fix bank_reconciliations NOT NULL Constraints
  
  1. Problem
    - Original table had `reconciliation_date` as NOT NULL with no default
    - Also had other NOT NULL columns (statement_balance, book_balance, reconciled_by)
    - Our new workflow uses different columns (statement_ending_balance, created_by, etc.)
    - Inserting new records fails due to missing required fields
    
  2. Solution (Non-Destructive)
    - Add DEFAULT CURRENT_DATE to reconciliation_date
    - Make old NOT NULL columns nullable (they're not used in new workflow)
    - This allows new workflow to work while preserving any old data
    
  3. Safety
    - No data loss (table is empty anyway)
    - Backward compatible
    - New columns already nullable from previous migration
*/

-- Add default to reconciliation_date for safety
ALTER TABLE bank_reconciliations
  ALTER COLUMN reconciliation_date SET DEFAULT CURRENT_DATE;

-- Make old NOT NULL columns nullable (not used in new workflow)
ALTER TABLE bank_reconciliations
  ALTER COLUMN statement_balance DROP NOT NULL;

ALTER TABLE bank_reconciliations
  ALTER COLUMN book_balance DROP NOT NULL;

ALTER TABLE bank_reconciliations
  ALTER COLUMN reconciled_by DROP NOT NULL;

-- Difference will be calculated, but let's allow NULL initially
ALTER TABLE bank_reconciliations
  ALTER COLUMN difference DROP NOT NULL;

-- Add helpful comment
COMMENT ON COLUMN bank_reconciliations.reconciliation_date IS 
  'Date of the reconciliation, typically the statement end date. Defaults to today.';

COMMENT ON COLUMN bank_reconciliations.statement_balance IS 
  'Legacy column - use statement_ending_balance instead';

COMMENT ON COLUMN bank_reconciliations.book_balance IS 
  'Legacy column - use cleared_balance or calculated_book_balance instead';

COMMENT ON COLUMN bank_reconciliations.reconciled_by IS 
  'Legacy column - use created_by, completed_by, etc. instead';
