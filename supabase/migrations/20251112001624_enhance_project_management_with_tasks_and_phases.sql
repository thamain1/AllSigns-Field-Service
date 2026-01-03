/*
  # Enhanced Project Management Schema

  ## Overview
  Extends the project management system with detailed task management, phases,
  resource allocation, change orders, and issue tracking capabilities.

  ## 1. New Tables

  ### Project Phases
    - `project_phases` - Major phases within a project
      - `id` (uuid, primary key)
      - `project_id` (uuid) - Foreign key to projects
      - `name` (text) - Phase name (Site Survey, Installation, etc.)
      - `description` (text)
      - `start_date` (date)
      - `end_date` (date)
      - `budget_labor` (numeric) - Labor budget for this phase
      - `budget_parts` (numeric) - Parts budget
      - `budget_equipment` (numeric) - Equipment budget
      - `actual_cost` (numeric) - Running total
      - `status` (milestone_status)
      - `sort_order` (integer)
      - `completion_percent` (numeric) - 0-100

  ### Project Tasks
    - `project_tasks` - Individual tasks within phases
      - `id` (uuid, primary key)
      - `project_id` (uuid) - Foreign key to projects
      - `phase_id` (uuid) - Foreign key to project_phases
      - `name` (text) - Task name
      - `description` (text)
      - `start_date` (date)
      - `end_date` (date)
      - `assigned_to` (uuid) - Foreign key to profiles
      - `estimated_hours` (numeric)
      - `actual_hours` (numeric)
      - `parts_cost` (numeric)
      - `equipment_cost` (numeric)
      - `status` (milestone_status)
      - `completion_percent` (numeric)
      - `dependencies` (text[]) - Array of task IDs that must complete first
      - `priority` (ticket_priority)
      - `sort_order` (integer)

  ### Resource Allocation
    - `project_resource_allocation` - Track resources assigned to tasks
      - `id` (uuid, primary key)
      - `task_id` (uuid) - Foreign key to project_tasks
      - `resource_type` (enum) - technician, part, equipment
      - `resource_id` (uuid) - ID of technician/part/equipment
      - `hours_allocated` (numeric) - For technicians
      - `quantity_allocated` (numeric) - For parts/equipment
      - `cost_allocated` (numeric) - Budgeted cost

  ### Change Orders
    - `project_change_orders` - Track scope/budget changes
      - `id` (uuid, primary key)
      - `project_id` (uuid) - Foreign key to projects
      - `change_number` (text) - CO-001, CO-002, etc.
      - `description` (text) - What changed
      - `reason` (text) - Why it changed
      - `cost_impact` (numeric) - Budget change
      - `time_impact_days` (integer) - Schedule change
      - `status` (enum) - pending, approved, rejected, implemented
      - `requested_by` (uuid) - Foreign key to profiles
      - `approved_by` (uuid) - Foreign key to profiles
      - `requested_date` (date)
      - `approved_date` (date)

  ### Project Issues
    - `project_issues` - Track risks and issues
      - `id` (uuid, primary key)
      - `project_id` (uuid) - Foreign key to projects
      - `issue_number` (text) - ISS-001, ISS-002, etc.
      - `type` (enum) - issue, risk
      - `title` (text)
      - `description` (text)
      - `severity` (enum) - low, medium, high, critical
      - `status` (enum) - open, in_progress, resolved, closed
      - `impact_cost` (numeric) - Cost impact
      - `impact_schedule_days` (integer) - Schedule impact
      - `assigned_to` (uuid) - Foreign key to profiles
      - `resolution` (text)
      - `created_by` (uuid)
      - `created_at` (timestamptz)
      - `resolved_at` (timestamptz)

  ## 2. Enhanced Budget Tracking
    - budget_labor, budget_parts, budget_equipment added to phases
    - Actual costs tracked at task level
    - Aggregate to phase and project level

  ## 3. Security
    - RLS enabled on all new tables
    - Same policies as existing project tables
*/

-- Create resource type enum
DO $$ BEGIN
  CREATE TYPE resource_type AS ENUM ('technician', 'part', 'equipment');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create change order status enum
DO $$ BEGIN
  CREATE TYPE change_order_status AS ENUM ('pending', 'approved', 'rejected', 'implemented');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create issue type enum
DO $$ BEGIN
  CREATE TYPE project_issue_type AS ENUM ('issue', 'risk');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create issue severity enum
DO $$ BEGIN
  CREATE TYPE issue_severity AS ENUM ('low', 'medium', 'high', 'critical');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create issue status enum
DO $$ BEGIN
  CREATE TYPE issue_status AS ENUM ('open', 'in_progress', 'resolved', 'closed');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create project phases table
CREATE TABLE IF NOT EXISTS project_phases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  start_date date NOT NULL,
  end_date date,
  budget_labor numeric(10,2) DEFAULT 0,
  budget_parts numeric(10,2) DEFAULT 0,
  budget_equipment numeric(10,2) DEFAULT 0,
  actual_cost numeric(10,2) DEFAULT 0,
  status milestone_status DEFAULT 'pending',
  sort_order integer DEFAULT 0,
  completion_percent numeric(5,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project tasks table
CREATE TABLE IF NOT EXISTS project_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  phase_id uuid REFERENCES project_phases(id) ON DELETE SET NULL,
  name text NOT NULL,
  description text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  estimated_hours numeric(10,2) DEFAULT 0,
  actual_hours numeric(10,2) DEFAULT 0,
  parts_cost numeric(10,2) DEFAULT 0,
  equipment_cost numeric(10,2) DEFAULT 0,
  status milestone_status DEFAULT 'pending',
  completion_percent numeric(5,2) DEFAULT 0,
  dependencies text[] DEFAULT ARRAY[]::text[],
  priority ticket_priority DEFAULT 'normal',
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create resource allocation table
CREATE TABLE IF NOT EXISTS project_resource_allocation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES project_tasks(id) ON DELETE CASCADE,
  resource_type resource_type NOT NULL,
  resource_id uuid NOT NULL,
  hours_allocated numeric(10,2) DEFAULT 0,
  quantity_allocated numeric(10,2) DEFAULT 0,
  cost_allocated numeric(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create change orders table
CREATE TABLE IF NOT EXISTS project_change_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  change_number text NOT NULL,
  description text NOT NULL,
  reason text,
  cost_impact numeric(10,2) DEFAULT 0,
  time_impact_days integer DEFAULT 0,
  status change_order_status DEFAULT 'pending',
  requested_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  approved_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  requested_date date DEFAULT CURRENT_DATE,
  approved_date date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project issues table
CREATE TABLE IF NOT EXISTS project_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  issue_number text NOT NULL,
  type project_issue_type DEFAULT 'issue',
  title text NOT NULL,
  description text,
  severity issue_severity DEFAULT 'medium',
  status issue_status DEFAULT 'open',
  impact_cost numeric(10,2) DEFAULT 0,
  impact_schedule_days integer DEFAULT 0,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  resolution text,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now(),
  resolved_at timestamptz,
  updated_at timestamptz DEFAULT now()
);

-- Add enhanced budget fields to projects
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'budget_labor'
  ) THEN
    ALTER TABLE projects ADD COLUMN budget_labor numeric(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'budget_parts'
  ) THEN
    ALTER TABLE projects ADD COLUMN budget_parts numeric(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'budget_equipment'
  ) THEN
    ALTER TABLE projects ADD COLUMN budget_equipment numeric(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'budget_travel'
  ) THEN
    ALTER TABLE projects ADD COLUMN budget_travel numeric(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'budget_overhead'
  ) THEN
    ALTER TABLE projects ADD COLUMN budget_overhead numeric(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'location'
  ) THEN
    ALTER TABLE projects ADD COLUMN location text;
  END IF;
END $$;

-- Link tickets to tasks
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'project_task_id'
  ) THEN
    ALTER TABLE tickets ADD COLUMN project_task_id uuid REFERENCES project_tasks(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Enable RLS
ALTER TABLE project_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_resource_allocation ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_change_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_issues ENABLE ROW LEVEL SECURITY;

-- Phase policies
CREATE POLICY "Authenticated users can view phases"
  ON project_phases FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage phases"
  ON project_phases FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Task policies
CREATE POLICY "Authenticated users can view tasks"
  ON project_tasks FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage tasks"
  ON project_tasks FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Resource allocation policies
CREATE POLICY "Authenticated users can view resources"
  ON project_resource_allocation FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage resources"
  ON project_resource_allocation FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Change order policies
CREATE POLICY "Authenticated users can view change orders"
  ON project_change_orders FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage change orders"
  ON project_change_orders FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Issue policies
CREATE POLICY "Authenticated users can view issues"
  ON project_issues FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can manage issues"
  ON project_issues FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_phases_project ON project_phases(project_id);
CREATE INDEX IF NOT EXISTS idx_phases_dates ON project_phases(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON project_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_phase ON project_tasks(phase_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON project_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_dates ON project_tasks(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_resources_task ON project_resource_allocation(task_id);
CREATE INDEX IF NOT EXISTS idx_change_orders_project ON project_change_orders(project_id);
CREATE INDEX IF NOT EXISTS idx_issues_project ON project_issues(project_id);
CREATE INDEX IF NOT EXISTS idx_issues_assigned ON project_issues(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tickets_task ON tickets(project_task_id);

-- Function to auto-generate project numbers
CREATE OR REPLACE FUNCTION generate_project_number()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  year_part text;
  sequence_num integer;
  new_number text;
BEGIN
  year_part := TO_CHAR(CURRENT_DATE, 'YYYY');
  
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(project_number FROM 'PRJ-' || year_part || '-(\d+)') AS INTEGER)
  ), 0) + 1
  INTO sequence_num
  FROM projects
  WHERE project_number LIKE 'PRJ-' || year_part || '-%';
  
  new_number := 'PRJ-' || year_part || '-' || LPAD(sequence_num::text, 4, '0');
  
  RETURN new_number;
END;
$$;

GRANT EXECUTE ON FUNCTION generate_project_number() TO authenticated;
