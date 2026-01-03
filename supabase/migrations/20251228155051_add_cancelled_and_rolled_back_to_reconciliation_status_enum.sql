/*
  # Add cancelled and rolled_back to reconciliation_status enum
  
  1. Problem
    - The reconciliation_status enum only has 'in_progress' and 'reconciled'
    - Need to support 'cancelled' and 'rolled_back' statuses
    - The cancel_bank_reconciliation function needs 'cancelled' status
    
  2. Solution
    - Add 'cancelled' and 'rolled_back' to the enum
    - Safe operation (only adds, doesn't change existing values)
    
  3. Impact
    - Existing data unaffected (remains 'in_progress' or 'reconciled')
    - New cancelled and rolled back operations will work correctly
*/

-- Add 'cancelled' to the enum (if it doesn't already exist)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'cancelled' 
    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'reconciliation_status')
  ) THEN
    ALTER TYPE reconciliation_status ADD VALUE 'cancelled';
  END IF;
END$$;

-- Add 'rolled_back' to the enum (if it doesn't already exist)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'rolled_back' 
    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'reconciliation_status')
  ) THEN
    ALTER TYPE reconciliation_status ADD VALUE 'rolled_back';
  END IF;
END$$;

-- Add 'completed' alias for 'reconciled' (for consistency with code)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'completed' 
    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'reconciliation_status')
  ) THEN
    ALTER TYPE reconciliation_status ADD VALUE 'completed';
  END IF;
END$$;
