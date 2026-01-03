/*
  # Add Master Project Support to Projects Table

  1. Additive Columns
    - is_master_project - Flag to identify master projects vs site jobs
    - parent_project_id - FK to parent master project
    - contract_value_total - Total contract value for master projects
    - contract_value_site - Contract value allocated to this site job
    - site_name - Name for site jobs
    - site_address - Physical address of site job
    - sequence_number - Order of sites within master

  2. Important Notes
    - All columns nullable to preserve existing data
    - Existing projects remain unchanged
    - No destructive changes
*/

-- Add master project flag
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'is_master_project'
  ) THEN
    ALTER TABLE projects ADD COLUMN is_master_project boolean DEFAULT false;
  END IF;
END $$;

-- Add parent project FK for site jobs
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'parent_project_id'
  ) THEN
    ALTER TABLE projects ADD COLUMN parent_project_id uuid REFERENCES projects(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Add contract values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'contract_value_total'
  ) THEN
    ALTER TABLE projects ADD COLUMN contract_value_total numeric(15, 2);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'contract_value_site'
  ) THEN
    ALTER TABLE projects ADD COLUMN contract_value_site numeric(15, 2);
  END IF;
END $$;

-- Add site-specific fields
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'site_name'
  ) THEN
    ALTER TABLE projects ADD COLUMN site_name text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'site_address'
  ) THEN
    ALTER TABLE projects ADD COLUMN site_address text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'sequence_number'
  ) THEN
    ALTER TABLE projects ADD COLUMN sequence_number integer;
  END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_projects_parent_id 
  ON projects(parent_project_id) WHERE parent_project_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_projects_is_master 
  ON projects(is_master_project) WHERE is_master_project = true;

-- Add constraint to prevent circular references
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'projects_no_self_parent'
  ) THEN
    ALTER TABLE projects 
    ADD CONSTRAINT projects_no_self_parent 
    CHECK (parent_project_id IS NULL OR parent_project_id != id);
  END IF;
END $$;

-- Add helpful comment
COMMENT ON COLUMN projects.is_master_project IS 'TRUE for master projects with multiple sites, FALSE for regular projects and site jobs';
COMMENT ON COLUMN projects.parent_project_id IS 'FK to master project if this is a site job, NULL for master projects and standalone projects';
COMMENT ON COLUMN projects.contract_value_total IS 'Total contract value across all sites (master projects only)';
COMMENT ON COLUMN projects.contract_value_site IS 'Contract value allocated to this specific site (site jobs only)';
