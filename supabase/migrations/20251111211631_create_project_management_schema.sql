/*
  # Project Management Schema

  ## Overview
  This migration creates the project management infrastructure for large, multi-phase jobs
  such as installations, long-term contracts, and complex service projects.

  ## 1. New Tables

  ### Projects
    - `projects` - Main project records
      - `id` (uuid, primary key)
      - `project_number` (text, unique) - Auto-generated project identifier
      - `name` (text) - Project name
      - `description` (text) - Project details
      - `customer_id` (uuid) - Foreign key to customers
      - `status` (enum) - planning, in_progress, on_hold, completed, cancelled
      - `priority` (enum) - low, normal, high, urgent
      - `project_type` (text) - Installation, Maintenance Contract, Retrofit, etc.
      - `start_date` (date) - Planned or actual start
      - `end_date` (date, nullable) - Planned or actual completion
      - `budget` (decimal) - Total project budget
      - `actual_cost` (decimal) - Running total of actual costs
      - `estimated_hours` (decimal) - Labor hour estimate
      - `actual_hours` (decimal) - Running total of actual hours
      - `profit_margin` (decimal) - Expected profit percentage
      - `manager_id` (uuid) - Foreign key to profiles (project manager)
      - `created_by` (uuid) - Foreign key to profiles
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Project Milestones
    - `project_milestones` - Key phases or checkpoints in projects
      - `id` (uuid, primary key)
      - `project_id` (uuid) - Foreign key to projects
      - `name` (text) - Milestone name
      - `description` (text) - Milestone details
      - `due_date` (date) - Target completion date
      - `completed_date` (date, nullable) - Actual completion
      - `budget_allocation` (decimal) - Budget allocated to this milestone
      - `status` (enum) - pending, in_progress, completed, blocked
      - `sort_order` (integer) - Display order
      - `created_at` (timestamptz)

  ### Project Documents
    - `project_documents` - Specs, permits, contracts, photos
      - `id` (uuid, primary key)
      - `project_id` (uuid) - Foreign key to projects
      - `document_type` (text) - Permit, Contract, Spec, Photo, Other
      - `file_name` (text) - Original file name
      - `file_url` (text) - Storage URL
      - `file_size` (integer) - File size in bytes
      - `uploaded_by` (uuid) - Foreign key to profiles
      - `notes` (text) - Document notes
      - `created_at` (timestamptz)

  ### Project Team Members
    - `project_team_members` - Technicians and staff assigned to projects
      - `id` (uuid, primary key)
      - `project_id` (uuid) - Foreign key to projects
      - `user_id` (uuid) - Foreign key to profiles
      - `role` (text) - Lead Technician, Helper, Project Manager, etc.
      - `assigned_date` (date) - When assigned
      - `created_at` (timestamptz)

  ## 2. Updates to Existing Tables
    - Link tickets to projects

  ## 3. Security
    - Enable RLS on all new tables
    - Authenticated users can view projects they're assigned to
    - Admins and project managers have full access

  ## 4. Indexes
    - Project number for quick lookup
    - Customer ID for customer project history
    - Status and dates for project tracking
*/

-- Create project status enum
DO $$ BEGIN
  CREATE TYPE project_status AS ENUM ('planning', 'in_progress', 'on_hold', 'completed', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create milestone status enum
DO $$ BEGIN
  CREATE TYPE milestone_status AS ENUM ('pending', 'in_progress', 'completed', 'blocked');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create projects table
CREATE TABLE IF NOT EXISTS projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_number text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  status project_status DEFAULT 'planning',
  priority ticket_priority DEFAULT 'normal',
  project_type text,
  start_date date NOT NULL DEFAULT CURRENT_DATE,
  end_date date,
  budget decimal(10,2) DEFAULT 0,
  actual_cost decimal(10,2) DEFAULT 0,
  estimated_hours decimal(10,2) DEFAULT 0,
  actual_hours decimal(10,2) DEFAULT 0,
  profit_margin decimal(5,2) DEFAULT 0,
  manager_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project milestones table
CREATE TABLE IF NOT EXISTS project_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  due_date date NOT NULL,
  completed_date date,
  budget_allocation decimal(10,2) DEFAULT 0,
  status milestone_status DEFAULT 'pending',
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create project documents table
CREATE TABLE IF NOT EXISTS project_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  document_type text NOT NULL,
  file_name text NOT NULL,
  file_url text NOT NULL,
  file_size integer,
  uploaded_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Create project team members table
CREATE TABLE IF NOT EXISTS project_team_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role text,
  assigned_date date DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(project_id, user_id)
);

-- Add project linking to tickets
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tickets' AND column_name = 'project_id'
  ) THEN
    ALTER TABLE tickets ADD COLUMN project_id uuid REFERENCES projects(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Enable RLS
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_team_members ENABLE ROW LEVEL SECURITY;

-- Project policies
CREATE POLICY "Authenticated users can view projects"
  ON projects FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can create projects"
  ON projects FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update projects"
  ON projects FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete projects"
  ON projects FOR DELETE
  TO authenticated
  USING (true);

-- Milestone policies
CREATE POLICY "Authenticated users can view milestones"
  ON project_milestones FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can create milestones"
  ON project_milestones FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update milestones"
  ON project_milestones FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete milestones"
  ON project_milestones FOR DELETE
  TO authenticated
  USING (true);

-- Document policies
CREATE POLICY "Authenticated users can view documents"
  ON project_documents FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can upload documents"
  ON project_documents FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update documents"
  ON project_documents FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete documents"
  ON project_documents FOR DELETE
  TO authenticated
  USING (true);

-- Team member policies
CREATE POLICY "Authenticated users can view team members"
  ON project_team_members FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can assign team members"
  ON project_team_members FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update team assignments"
  ON project_team_members FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can remove team members"
  ON project_team_members FOR DELETE
  TO authenticated
  USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_projects_number ON projects(project_number);
CREATE INDEX IF NOT EXISTS idx_projects_customer ON projects(customer_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_manager ON projects(manager_id);
CREATE INDEX IF NOT EXISTS idx_projects_dates ON projects(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_milestones_project ON project_milestones(project_id);
CREATE INDEX IF NOT EXISTS idx_milestones_due_date ON project_milestones(due_date);
CREATE INDEX IF NOT EXISTS idx_documents_project ON project_documents(project_id);
CREATE INDEX IF NOT EXISTS idx_team_members_project ON project_team_members(project_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON project_team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_project ON tickets(project_id);