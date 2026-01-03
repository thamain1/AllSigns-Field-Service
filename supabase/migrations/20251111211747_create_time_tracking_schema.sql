/*
  # Time Tracking Schema (Time Clock Module)

  ## Overview
  This migration creates the time tracking infrastructure for logging technician and staff time
  for payroll, job costing, compliance, and invoicing purposes.

  ## 1. New Tables

  ### Time Logs
    - `time_logs` - Individual time clock entries
      - `id` (uuid, primary key)
      - `user_id` (uuid) - Foreign key to profiles
      - `clock_in_time` (timestamptz) - When user clocked in
      - `clock_out_time` (timestamptz, nullable) - When user clocked out
      - `total_hours` (decimal, nullable) - Calculated hours worked
      - `break_duration` (decimal) - Break time in hours
      - `ticket_id` (uuid, nullable) - Associated ticket/job
      - `project_id` (uuid, nullable) - Associated project
      - `time_type` (enum) - regular, overtime, travel, on_site, break
      - `status` (enum) - active, completed, approved, rejected
      - `location_lat` (decimal, nullable) - GPS latitude (optional)
      - `location_lng` (decimal, nullable) - GPS longitude (optional)
      - `notes` (text) - Time entry notes
      - `approved_by` (uuid, nullable) - Foreign key to profiles (manager)
      - `approved_at` (timestamptz, nullable) - When approved
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Time Adjustments
    - `time_adjustments` - Manual adjustments to time entries
      - `id` (uuid, primary key)
      - `time_log_id` (uuid) - Foreign key to time_logs
      - `adjustment_type` (text) - correction, bonus, penalty, other
      - `hours_adjusted` (decimal) - Hours added or subtracted
      - `reason` (text) - Reason for adjustment
      - `adjusted_by` (uuid) - Foreign key to profiles (admin/manager)
      - `created_at` (timestamptz)

  ## 2. Integration Points
    - Link time logs to tickets for job costing
    - Link time logs to projects for project tracking
    - Feed into payroll calculations
    - Track time per technician for capacity planning

  ## 3. Security
    - Enable RLS on all new tables
    - Users can view and manage their own time logs
    - Managers/admins can view and approve all time logs
    - Only admins can make time adjustments

  ## 4. Indexes
    - User ID for personal time tracking
    - Clock in/out times for date range queries
    - Ticket and project IDs for job costing
    - Status for approval workflows
*/

-- Create time type enum
DO $$ BEGIN
  CREATE TYPE time_log_type AS ENUM ('regular', 'overtime', 'travel', 'on_site', 'break');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create time log status enum
DO $$ BEGIN
  CREATE TYPE time_log_status AS ENUM ('active', 'completed', 'approved', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create time logs table
CREATE TABLE IF NOT EXISTS time_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  clock_in_time timestamptz NOT NULL,
  clock_out_time timestamptz,
  total_hours decimal(10,2),
  break_duration decimal(10,2) DEFAULT 0,
  ticket_id uuid REFERENCES tickets(id) ON DELETE SET NULL,
  project_id uuid REFERENCES projects(id) ON DELETE SET NULL,
  time_type time_log_type DEFAULT 'regular',
  status time_log_status DEFAULT 'active',
  location_lat decimal(10,7),
  location_lng decimal(10,7),
  notes text,
  approved_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  approved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create time adjustments table
CREATE TABLE IF NOT EXISTS time_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  time_log_id uuid NOT NULL REFERENCES time_logs(id) ON DELETE CASCADE,
  adjustment_type text NOT NULL,
  hours_adjusted decimal(10,2) NOT NULL,
  reason text NOT NULL,
  adjusted_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE time_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_adjustments ENABLE ROW LEVEL SECURITY;

-- Time log policies - users can view their own, admins/dispatchers can view all
CREATE POLICY "Users can view own time logs"
  ON time_logs FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Users can create own time logs"
  ON time_logs FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own time logs"
  ON time_logs FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  )
  WITH CHECK (
    auth.uid() = user_id
    OR
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Admins can delete time logs"
  ON time_logs FOR DELETE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Time adjustment policies - only admins and dispatchers
CREATE POLICY "Managers can view time adjustments"
  ON time_adjustments FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Managers can create time adjustments"
  ON time_adjustments FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Managers can update time adjustments"
  ON time_adjustments FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Admins can delete time adjustments"
  ON time_adjustments FOR DELETE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_time_logs_user ON time_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_time_logs_clock_in ON time_logs(clock_in_time);
CREATE INDEX IF NOT EXISTS idx_time_logs_clock_out ON time_logs(clock_out_time);
CREATE INDEX IF NOT EXISTS idx_time_logs_ticket ON time_logs(ticket_id);
CREATE INDEX IF NOT EXISTS idx_time_logs_project ON time_logs(project_id);
CREATE INDEX IF NOT EXISTS idx_time_logs_status ON time_logs(status);
CREATE INDEX IF NOT EXISTS idx_time_adjustments_log ON time_adjustments(time_log_id);