/*
  # Enhance Project Management with Tasks, Phases, and Resources

  ## Overview
  Extends existing project management with detailed task management, resource allocation,
  change orders, issues tracking, and project templates for complete PM functionality.

  ## New Tables
    - project_phases: Organize work into phases (replaces basic milestones)
    - project_tasks: Detailed task management with dependencies
    - project_resource_allocations: Track technician/part/equipment allocation
    - project_change_orders: Change management
    - project_issues: Issues and risks tracking
    - project_templates: Reusable project templates

  ## Integration Points
    - Link tickets to project tasks
    - Link time logs to project tasks
    - Track resource usage per task
*/

-- Create additional enums
DO $$ BEGIN CREATE TYPE task_status AS ENUM ('not_started', 'in_progress', 'completed', 'blocked', 'cancelled'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE resource_type AS ENUM ('technician', 'part', 'equipment'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE change_order_status AS ENUM ('pending', 'approved', 'rejected', 'implemented'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE issue_type AS ENUM ('issue', 'risk', 'blocker'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE issue_severity AS ENUM ('low', 'medium', 'high', 'critical'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE issue_status AS ENUM ('open', 'in_progress', 'resolved', 'closed'); EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Create project phases table (enhanced milestones)
CREATE TABLE IF NOT EXISTS project_phases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  phase_order integer DEFAULT 0,
  start_date date NOT NULL,
  end_date date NOT NULL,
  budget_amount decimal(10,2) DEFAULT 0,
  actual_amount decimal(10,2) DEFAULT 0,
  status milestone_status DEFAULT 'pending',
  percent_complete integer DEFAULT 0,
  is_milestone boolean DEFAULT false,
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
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  estimated_hours decimal(10,2) DEFAULT 0,
  actual_hours decimal(10,2) DEFAULT 0,
  status task_status DEFAULT 'not_started',
  priority ticket_priority DEFAULT 'normal',
  percent_complete integer DEFAULT 0,
  dependencies text[] DEFAULT '{}',
  location text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project resource allocations table
CREATE TABLE IF NOT EXISTS project_resource_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES project_tasks(id) ON DELETE CASCADE,
  resource_type resource_type NOT NULL,
  resource_id uuid NOT NULL,
  quantity decimal(10,2) DEFAULT 0,
  hours_allocated decimal(10,2) DEFAULT 0,
  cost_allocated decimal(10,2) DEFAULT 0,
  actual_quantity decimal(10,2) DEFAULT 0,
  actual_cost decimal(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project change orders table
CREATE TABLE IF NOT EXISTS project_change_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  change_number text NOT NULL,
  description text NOT NULL,
  reason text,
  cost_impact decimal(10,2) DEFAULT 0,
  time_impact_days integer DEFAULT 0,
  status change_order_status DEFAULT 'pending',
  requested_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  approved_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  approved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project issues table
CREATE TABLE IF NOT EXISTS project_issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  task_id uuid REFERENCES project_tasks(id) ON DELETE SET NULL,
  issue_type issue_type DEFAULT 'issue',
  title text NOT NULL,
  description text,
  severity issue_severity DEFAULT 'medium',
  status issue_status DEFAULT 'open',
  impact_cost decimal(10,2) DEFAULT 0,
  impact_schedule_days integer DEFAULT 0,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  resolution text,
  resolved_at timestamptz,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create project templates table
CREATE TABLE IF NOT EXISTS project_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_name text NOT NULL,
  description text,
  category text,
  default_budget decimal(10,2) DEFAULT 0,
  default_duration_days integer DEFAULT 30,
  is_active boolean DEFAULT true,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now()
);

-- Create project template phases table
CREATE TABLE IF NOT EXISTS project_template_phases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid NOT NULL REFERENCES project_templates(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  phase_order integer DEFAULT 0,
  duration_days integer DEFAULT 7,
  budget_percent decimal(5,2) DEFAULT 0,
  is_milestone boolean DEFAULT false
);

-- Create project template tasks table
CREATE TABLE IF NOT EXISTS project_template_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_phase_id uuid NOT NULL REFERENCES project_template_phases(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  estimated_hours decimal(10,2) DEFAULT 0,
  task_order integer DEFAULT 0
);

-- Add project links to existing tables
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tickets' AND column_name = 'project_task_id') THEN ALTER TABLE tickets ADD COLUMN project_task_id uuid REFERENCES project_tasks(id) ON DELETE SET NULL; END IF; END $$;

DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'time_logs' AND column_name = 'project_task_id') THEN ALTER TABLE time_logs ADD COLUMN project_task_id uuid REFERENCES project_tasks(id) ON DELETE SET NULL; END IF; END $$;

-- Enable RLS
ALTER TABLE project_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_resource_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_change_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_template_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_template_tasks ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "phases_all" ON project_phases FOR ALL TO authenticated USING (true);
CREATE POLICY "tasks_all" ON project_tasks FOR ALL TO authenticated USING (true);
CREATE POLICY "allocations_all" ON project_resource_allocations FOR ALL TO authenticated USING (true);
CREATE POLICY "change_orders_all" ON project_change_orders FOR ALL TO authenticated USING (true);
CREATE POLICY "issues_all" ON project_issues FOR ALL TO authenticated USING (true);
CREATE POLICY "templates_all" ON project_templates FOR ALL TO authenticated USING (true);
CREATE POLICY "template_phases_all" ON project_template_phases FOR ALL TO authenticated USING (true);
CREATE POLICY "template_tasks_all" ON project_template_tasks FOR ALL TO authenticated USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_phases_project ON project_phases(project_id);
CREATE INDEX IF NOT EXISTS idx_phases_order ON project_phases(project_id, phase_order);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON project_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_phase ON project_tasks(phase_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON project_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON project_tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_dates ON project_tasks(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_allocations_project ON project_resource_allocations(project_id);
CREATE INDEX IF NOT EXISTS idx_allocations_task ON project_resource_allocations(task_id);
CREATE INDEX IF NOT EXISTS idx_allocations_resource ON project_resource_allocations(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_change_orders_project ON project_change_orders(project_id);
CREATE INDEX IF NOT EXISTS idx_issues_project ON project_issues(project_id);
CREATE INDEX IF NOT EXISTS idx_issues_status ON project_issues(status);
CREATE INDEX IF NOT EXISTS idx_tickets_project_task ON tickets(project_task_id);
CREATE INDEX IF NOT EXISTS idx_time_logs_project_task ON time_logs(project_task_id);
