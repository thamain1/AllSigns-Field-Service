/*
  # Remove Duplicate Indexes

  This migration removes duplicate indexes that provide the same functionality,
  keeping only one index per unique column/set of columns.

  ## Indexes Removed
  - idx_tickets_project_id (duplicate of idx_tickets_project)
  - idx_tickets_task (duplicate of idx_tickets_project_task)
*/

-- Drop duplicate ticket indexes
DROP INDEX IF EXISTS public.idx_tickets_project_id;
DROP INDEX IF EXISTS public.idx_tickets_task;
