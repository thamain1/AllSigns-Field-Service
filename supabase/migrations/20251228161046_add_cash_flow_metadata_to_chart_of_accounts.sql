/*
  # Add Cash Flow Metadata to Chart of Accounts
  
  1. Purpose
    - Enable Cash Flow Statement generation using the direct method
    - Track which accounts are cash/bank accounts
    - Allow classification of cash flows by section (Operating, Investing, Financing)
    
  2. New Columns Added
    - `is_cash_account` (boolean, default false)
      - Identifies cash and bank accounts
      - Used to determine which GL entries represent actual cash movements
    - `cash_flow_section` (text, nullable)
      - Optional override to classify cash flows
      - Values: 'operating', 'investing', 'financing', 'non_cash'
      - When NULL, section is derived algorithmically from account_type and subtype
    
  3. Classification Logic
    - When a GL entry affects a cash account, look at the offsetting (non-cash) accounts
    - Use cash_flow_section if set on the offsetting account
    - Otherwise derive from account_type:
      - Fixed assets, long-term investments → Investing
      - Long-term debt, equity, owner draws → Financing
      - Revenue, expenses, AR, AP, inventory → Operating
    
  4. Safety
    - Additive only (no existing columns dropped or renamed)
    - Default values ensure existing functionality unaffected
    - NULL cash_flow_section means use automatic classification
*/

-- Add is_cash_account column
ALTER TABLE chart_of_accounts
ADD COLUMN IF NOT EXISTS is_cash_account BOOLEAN DEFAULT false NOT NULL;

-- Add cash_flow_section column
ALTER TABLE chart_of_accounts
ADD COLUMN IF NOT EXISTS cash_flow_section TEXT;

-- Add check constraint for valid cash_flow_section values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'valid_cash_flow_section'
  ) THEN
    ALTER TABLE chart_of_accounts
    ADD CONSTRAINT valid_cash_flow_section 
    CHECK (cash_flow_section IS NULL OR cash_flow_section IN ('operating', 'investing', 'financing', 'non_cash'));
  END IF;
END $$;

-- Create index for efficient cash account queries
CREATE INDEX IF NOT EXISTS idx_chart_of_accounts_is_cash_account 
ON chart_of_accounts(is_cash_account) WHERE is_cash_account = true;

-- Add helpful comments
COMMENT ON COLUMN chart_of_accounts.is_cash_account IS 
  'Identifies cash and bank accounts for Cash Flow Statement generation. Set to true for checking, savings, petty cash, and similar liquid asset accounts.';

COMMENT ON COLUMN chart_of_accounts.cash_flow_section IS 
  'Optional override for cash flow classification. When NULL, section is automatically derived from account type and subtype. Values: operating, investing, financing, non_cash.';
