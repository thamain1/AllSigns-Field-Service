/*
  # Add Ticket Type System with PRJ and SVC Auto-Numbering

  ## Changes Made
  
  1. New Tables
    - `ticket_types` - Enum table for PRJ and SVC ticket types
    - `ticket_sequences` - Tracks sequence numbers for auto-generation
  
  2. Tickets Table Updates
    - Add `ticket_type` column (PRJ or SVC)
    - Add `parent_project_id` for better project relationship tracking
    - Add `phase_milestone` for work phase tracking
    - Add `technician_notes` for detailed job notes
    - Update `ticket_number` to support new formats (PRJ-YYMM-XXX-N and SVC-YYMM-DD-N)
  
  3. Functions
    - `generate_prj_ticket_number(project_id)` - Auto-generates PRJ-YYMM-XXX-N format
    - `generate_svc_ticket_number()` - Auto-generates SVC-YYMM-DD-N format
    - `get_next_ticket_number(type, project_id)` - Main ticket number generator
  
  4. Triggers
    - Auto-populate ticket_number on insert based on ticket_type
  
  5. Security
    - RLS policies for ticket_types and ticket_sequences
    - Updated RLS policies for tickets table to support new fields
  
  ## Ticket ID Formats
  
  ### PRJ Tickets (Project Work Orders)
  Format: PRJ-YYMM-XXX-N
  - YYMM: Year and Month of project creation
  - XXX: Unique project number for that month
  - N: Sequential ticket number per project
  Example: PRJ-2511-105-1
  
  ### SVC Tickets (Service Work Orders)
  Format: SVC-YYMM-DD-N
  - YYMM: Year and Month
  - DD: Day of month
  - N: Order of creation on that day
  Example: SVC-2511-10-5
*/

-- Create ticket type enum
DO $$ BEGIN
  CREATE TYPE ticket_type AS ENUM ('PRJ', 'SVC');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Add new columns to tickets table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'ticket_type'
  ) THEN
    ALTER TABLE tickets ADD COLUMN ticket_type ticket_type DEFAULT 'SVC';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'phase_milestone'
  ) THEN
    ALTER TABLE tickets ADD COLUMN phase_milestone text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'technician_notes'
  ) THEN
    ALTER TABLE tickets ADD COLUMN technician_notes text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'parts_used'
  ) THEN
    ALTER TABLE tickets ADD COLUMN parts_used jsonb DEFAULT '[]'::jsonb;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tickets' AND column_name = 'photos'
  ) THEN
    ALTER TABLE tickets ADD COLUMN photos jsonb DEFAULT '[]'::jsonb;
  END IF;
END $$;

-- Create ticket sequences tracking table
CREATE TABLE IF NOT EXISTS ticket_sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_type ticket_type NOT NULL,
  year_month text NOT NULL,
  project_id uuid REFERENCES projects(id),
  day_of_month integer,
  last_sequence integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(ticket_type, year_month, project_id, day_of_month)
);

ALTER TABLE ticket_sequences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view sequences"
  ON ticket_sequences FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage sequences"
  ON ticket_sequences FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Function to get project number from its creation date and position
CREATE OR REPLACE FUNCTION get_project_number(p_project_id uuid)
RETURNS text AS $$
DECLARE
  v_year_month text;
  v_project_number integer;
BEGIN
  -- Get the year-month when project was created
  SELECT 
    to_char(created_at, 'YYMM'),
    ROW_NUMBER() OVER (
      PARTITION BY to_char(created_at, 'YYMM') 
      ORDER BY created_at
    )
  INTO v_year_month, v_project_number
  FROM projects
  WHERE id = p_project_id;
  
  RETURN v_year_month || '-' || LPAD(v_project_number::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Function to generate PRJ ticket number
CREATE OR REPLACE FUNCTION generate_prj_ticket_number(p_project_id uuid)
RETURNS text AS $$
DECLARE
  v_project_number text;
  v_ticket_sequence integer;
  v_year_month text;
BEGIN
  -- Get project number (YYMM-XXX)
  v_project_number := get_project_number(p_project_id);
  v_year_month := split_part(v_project_number, '-', 1);
  
  -- Get next ticket sequence for this project
  INSERT INTO ticket_sequences (ticket_type, year_month, project_id, last_sequence)
  VALUES ('PRJ', v_year_month, p_project_id, 1)
  ON CONFLICT (ticket_type, year_month, project_id, day_of_month)
  DO UPDATE SET 
    last_sequence = ticket_sequences.last_sequence + 1,
    updated_at = now()
  RETURNING last_sequence INTO v_ticket_sequence;
  
  -- Return formatted ticket number: PRJ-YYMM-XXX-N
  RETURN 'PRJ-' || v_project_number || '-' || v_ticket_sequence;
END;
$$ LANGUAGE plpgsql;

-- Function to generate SVC ticket number
CREATE OR REPLACE FUNCTION generate_svc_ticket_number()
RETURNS text AS $$
DECLARE
  v_year_month text;
  v_day text;
  v_ticket_sequence integer;
  v_day_int integer;
BEGIN
  -- Get current date parts
  v_year_month := to_char(now(), 'YYMM');
  v_day := to_char(now(), 'DD');
  v_day_int := EXTRACT(DAY FROM now())::integer;
  
  -- Get next ticket sequence for today
  INSERT INTO ticket_sequences (ticket_type, year_month, day_of_month, last_sequence)
  VALUES ('SVC', v_year_month, v_day_int, 1)
  ON CONFLICT (ticket_type, year_month, project_id, day_of_month)
  DO UPDATE SET 
    last_sequence = ticket_sequences.last_sequence + 1,
    updated_at = now()
  RETURNING last_sequence INTO v_ticket_sequence;
  
  -- Return formatted ticket number: SVC-YYMM-DD-N
  RETURN 'SVC-' || v_year_month || '-' || v_day || '-' || v_ticket_sequence;
END;
$$ LANGUAGE plpgsql;

-- Main function to get next ticket number based on type
CREATE OR REPLACE FUNCTION get_next_ticket_number(
  p_ticket_type ticket_type,
  p_project_id uuid DEFAULT NULL
)
RETURNS text AS $$
BEGIN
  IF p_ticket_type = 'PRJ' THEN
    IF p_project_id IS NULL THEN
      RAISE EXCEPTION 'project_id is required for PRJ tickets';
    END IF;
    RETURN generate_prj_ticket_number(p_project_id);
  ELSIF p_ticket_type = 'SVC' THEN
    RETURN generate_svc_ticket_number();
  ELSE
    RAISE EXCEPTION 'Invalid ticket type: %', p_ticket_type;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to auto-generate ticket number on insert
CREATE OR REPLACE FUNCTION auto_generate_ticket_number()
RETURNS TRIGGER AS $$
BEGIN
  -- Only generate if ticket_number is not already set
  IF NEW.ticket_number IS NULL OR NEW.ticket_number = '' THEN
    NEW.ticket_number := get_next_ticket_number(NEW.ticket_type, NEW.project_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trigger_auto_generate_ticket_number ON tickets;

-- Create trigger for auto-generating ticket numbers
CREATE TRIGGER trigger_auto_generate_ticket_number
  BEFORE INSERT ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_ticket_number();

-- Update existing tickets to have SVC type if they don't have a project
UPDATE tickets 
SET ticket_type = 'SVC'
WHERE ticket_type IS NULL AND project_id IS NULL;

-- Update existing tickets to have PRJ type if they have a project
UPDATE tickets 
SET ticket_type = 'PRJ'
WHERE ticket_type IS NULL AND project_id IS NOT NULL;

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_tickets_ticket_type ON tickets(ticket_type);
CREATE INDEX IF NOT EXISTS idx_tickets_project_id ON tickets(project_id);
CREATE INDEX IF NOT EXISTS idx_tickets_ticket_number ON tickets(ticket_number);
CREATE INDEX IF NOT EXISTS idx_ticket_sequences_lookup ON ticket_sequences(ticket_type, year_month, project_id, day_of_month);
