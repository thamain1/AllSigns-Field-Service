/*
  # Add Progress Tracking to Import Batches

  1. New Columns
    - `phase` - More granular status tracking (uploading, mapping, validating, ready_to_commit, committing, completed, failed, rolled_back)
    - `validated_rows` - Count of rows that passed validation
    - `committed_rows` - Count of rows successfully committed to live tables
    - `last_error_at` - Timestamp of last error encountered
    - `last_error_message` - Most recent error message for quick reference

  2. Changes
    - All changes are additive only - no existing columns modified
    - Existing imports will continue to work
    - New imports will populate these fields for better observability

  ## Purpose
  Enable real-time progress monitoring and detailed batch inspection without changing import pipeline
*/

-- Add phase enum for granular progress tracking
DO $$ BEGIN
  CREATE TYPE import_phase AS ENUM (
    'uploading',
    'mapping', 
    'validating',
    'ready_to_commit',
    'committing',
    'completed',
    'failed',
    'rolled_back'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Add progress tracking columns to import_batches (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_batches' AND column_name = 'phase'
  ) THEN
    ALTER TABLE import_batches ADD COLUMN phase import_phase DEFAULT 'uploading';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_batches' AND column_name = 'validated_rows'
  ) THEN
    ALTER TABLE import_batches ADD COLUMN validated_rows integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_batches' AND column_name = 'committed_rows'
  ) THEN
    ALTER TABLE import_batches ADD COLUMN committed_rows integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_batches' AND column_name = 'last_error_at'
  ) THEN
    ALTER TABLE import_batches ADD COLUMN last_error_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_batches' AND column_name = 'last_error_message'
  ) THEN
    ALTER TABLE import_batches ADD COLUMN last_error_message text;
  END IF;
END $$;

-- Create index for phase filtering
CREATE INDEX IF NOT EXISTS idx_import_batches_phase ON import_batches(phase);

-- Function to sync phase with status (for backward compatibility)
CREATE OR REPLACE FUNCTION sync_import_batch_phase()
RETURNS TRIGGER AS $$
BEGIN
  -- Auto-set phase based on status if phase is not explicitly set
  IF NEW.phase IS NULL OR NEW.phase = OLD.phase THEN
    CASE NEW.status
      WHEN 'pending' THEN NEW.phase := 'uploading';
      WHEN 'validating' THEN NEW.phase := 'validating';
      WHEN 'validated' THEN NEW.phase := 'ready_to_commit';
      WHEN 'importing' THEN NEW.phase := 'committing';
      WHEN 'completed' THEN NEW.phase := 'completed';
      WHEN 'failed' THEN NEW.phase := 'failed';
      WHEN 'rolled_back' THEN NEW.phase := 'rolled_back';
    END CASE;
  END IF;

  -- Sync validated_rows with rows_valid if not explicitly set
  IF NEW.validated_rows = 0 AND NEW.rows_valid > 0 THEN
    NEW.validated_rows := NEW.rows_valid;
  END IF;

  -- Sync committed_rows with rows_imported if not explicitly set
  IF NEW.committed_rows = 0 AND NEW.rows_imported > 0 THEN
    NEW.committed_rows := NEW.rows_imported;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-sync phase with status
DROP TRIGGER IF EXISTS trigger_sync_import_batch_phase ON import_batches;
CREATE TRIGGER trigger_sync_import_batch_phase
  BEFORE INSERT OR UPDATE ON import_batches
  FOR EACH ROW
  EXECUTE FUNCTION sync_import_batch_phase();

-- Backfill phase for existing batches
UPDATE import_batches
SET phase = CASE status
  WHEN 'pending' THEN 'uploading'::import_phase
  WHEN 'validating' THEN 'validating'::import_phase
  WHEN 'validated' THEN 'ready_to_commit'::import_phase
  WHEN 'importing' THEN 'committing'::import_phase
  WHEN 'completed' THEN 'completed'::import_phase
  WHEN 'failed' THEN 'failed'::import_phase
  WHEN 'rolled_back' THEN 'rolled_back'::import_phase
END
WHERE phase IS NULL;

-- Backfill validated_rows from rows_valid
UPDATE import_batches
SET validated_rows = rows_valid
WHERE validated_rows = 0 AND rows_valid > 0;

-- Backfill committed_rows from rows_imported
UPDATE import_batches
SET committed_rows = rows_imported
WHERE committed_rows = 0 AND rows_imported > 0;
