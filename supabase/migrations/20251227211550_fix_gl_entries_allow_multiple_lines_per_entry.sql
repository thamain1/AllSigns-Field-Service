/*
  # Fix GL Entries to Allow Multiple Lines Per Entry Number

  ## Overview
  In double-entry accounting, a single journal entry has multiple lines (e.g., one debit
  and one credit line), all sharing the same entry_number. The original schema incorrectly
  had a UNIQUE constraint on entry_number, preventing this.

  ## Changes
  - Drop the UNIQUE constraint on gl_entries.entry_number
  - Add a non-unique index for performance
  - Add a CHECK constraint to ensure at least debit or credit is non-zero

  ## Important Notes
  - This fixes the core issue preventing invoice posting
  - Multiple GL entry lines can now share the same entry_number (correct accounting behavior)
  - The entry_number + line combination is now the logical key
*/

-- Drop the unique constraint on entry_number
ALTER TABLE gl_entries DROP CONSTRAINT IF EXISTS gl_entries_entry_number_key;

-- Add a non-unique index for query performance
CREATE INDEX IF NOT EXISTS idx_gl_entries_entry_number_lookup ON gl_entries(entry_number);

-- Add a check constraint to ensure valid entries (at least one amount must be non-zero)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'gl_entries_amount_check'
      AND table_name = 'gl_entries'
  ) THEN
    ALTER TABLE gl_entries ADD CONSTRAINT gl_entries_amount_check
      CHECK (debit_amount > 0 OR credit_amount > 0);
  END IF;
END $$;

-- Update the view comment to clarify this behavior
COMMENT ON TABLE gl_entries IS 'General Ledger entries. Multiple lines can share the same entry_number to form a complete journal entry.';
COMMENT ON COLUMN gl_entries.entry_number IS 'Journal entry number. Multiple lines share the same entry_number.';
