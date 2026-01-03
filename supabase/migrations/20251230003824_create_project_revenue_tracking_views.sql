/*
  # Create Project Revenue Tracking Views and Functions

  1. Views
    - v_project_financial_summary - Per-project financial metrics
    - v_master_project_rollup - Master project with all site rollups
    - v_site_jobs_summary - All site jobs with their metrics

  2. Functions
    - get_master_project_percent_complete - Calculate completion %
    - get_project_cost_to_date - Calculate project costs

  3. Important Notes
    - All read-only views
    - No modifications to base tables
    - Leverages existing GL and job cost data
*/

-- =====================================================
-- PROJECT COST CALCULATION FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION get_project_cost_to_date(p_project_id uuid)
RETURNS numeric AS $$
DECLARE
  v_labor_cost numeric := 0;
  v_parts_cost numeric := 0;
  v_other_cost numeric := 0;
BEGIN
  -- Get labor costs from time logs
  SELECT COALESCE(SUM(tl.billing_amount), 0)
  INTO v_labor_cost
  FROM time_logs tl
  WHERE tl.project_id = p_project_id;
  
  -- Get parts costs from tickets linked to project
  SELECT COALESCE(SUM(tp.quantity * tp.unit_cost), 0)
  INTO v_parts_cost
  FROM ticket_parts tp
  JOIN tickets t ON t.id = tp.ticket_id
  WHERE t.project_id = p_project_id;
  
  -- Could add other cost sources here (POs, equipment, etc.)
  
  RETURN v_labor_cost + v_parts_cost + v_other_cost;
END;
$$ LANGUAGE plpgsql STABLE;

-- =====================================================
-- PROJECT FINANCIAL SUMMARY VIEW
-- =====================================================

CREATE OR REPLACE VIEW v_project_financial_summary AS
SELECT 
  p.id as project_id,
  p.project_number,
  p.name as project_name,
  p.customer_id,
  p.status as project_status,
  p.is_master_project,
  p.parent_project_id,
  p.site_name,
  
  -- Contract values
  COALESCE(p.contract_value_site, p.contract_value_total, p.budget) as contract_value,
  p.contract_value_total,
  p.contract_value_site,
  
  -- Billing metrics
  COALESCE(SUM(CASE WHEN i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) as billed_to_date,
  COALESCE(SUM(CASE WHEN ili.is_deposit = true AND i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) as deposits_billed,
  get_unreleased_deposit_amount(p.id) as deposits_unreleased,
  COALESCE(SUM(CASE WHEN ili.is_deposit = false AND i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) as revenue_recognized,
  
  -- Cost metrics
  get_project_cost_to_date(p.id) as cost_to_date,
  
  -- Calculated metrics
  COALESCE(SUM(CASE WHEN ili.is_deposit = false AND i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) - 
    get_project_cost_to_date(p.id) as gross_profit,
  
  CASE 
    WHEN COALESCE(SUM(CASE WHEN ili.is_deposit = false AND i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) > 0 THEN
      ((COALESCE(SUM(CASE WHEN ili.is_deposit = false AND i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) - 
        get_project_cost_to_date(p.id)) / 
       COALESCE(SUM(CASE WHEN ili.is_deposit = false AND i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) * 100)
    ELSE 0
  END as gross_margin_percent,
  
  COALESCE(p.contract_value_site, p.contract_value_total, p.budget, 0) - 
    COALESCE(SUM(CASE WHEN i.status != 'cancelled' THEN ili.line_total ELSE 0 END), 0) as unbilled_amount,
  
  -- Milestone tracking
  (SELECT COUNT(*) FROM project_billing_schedules pbs WHERE pbs.project_id = p.id) as total_milestones,
  (SELECT COUNT(*) FROM project_billing_schedules pbs WHERE pbs.project_id = p.id AND pbs.status = 'billed') as completed_milestones,
  
  -- Metadata
  p.start_date,
  p.end_date,
  p.created_at,
  p.updated_at

FROM projects p
LEFT JOIN invoice_line_items ili ON ili.project_id = p.id
LEFT JOIN invoices i ON i.id = ili.invoice_id
GROUP BY 
  p.id, p.project_number, p.name, p.customer_id, p.status,
  p.is_master_project, p.parent_project_id, p.site_name,
  p.contract_value_total, p.contract_value_site, p.budget,
  p.start_date, p.end_date, p.created_at, p.updated_at;

-- Grant access
GRANT SELECT ON v_project_financial_summary TO authenticated;

-- =====================================================
-- SITE JOBS SUMMARY VIEW
-- =====================================================

CREATE OR REPLACE VIEW v_site_jobs_summary AS
SELECT 
  p.id as site_job_id,
  p.parent_project_id as master_project_id,
  mp.project_number as master_project_number,
  mp.name as master_project_name,
  p.project_number as site_project_number,
  p.name as site_project_name,
  p.site_name,
  p.site_address,
  p.sequence_number,
  p.status as site_status,
  p.customer_id,
  
  -- Financial summary
  pfs.contract_value,
  pfs.billed_to_date,
  pfs.deposits_billed,
  pfs.deposits_unreleased,
  pfs.revenue_recognized,
  pfs.cost_to_date,
  pfs.gross_profit,
  pfs.gross_margin_percent,
  pfs.unbilled_amount,
  
  -- Milestone progress
  pfs.total_milestones,
  pfs.completed_milestones,
  CASE 
    WHEN pfs.total_milestones > 0 THEN 
      (pfs.completed_milestones::numeric / pfs.total_milestones * 100)
    ELSE 0
  END as milestone_completion_percent,
  
  -- Dates
  p.start_date,
  p.end_date,
  p.created_at

FROM projects p
JOIN projects mp ON mp.id = p.parent_project_id
LEFT JOIN v_project_financial_summary pfs ON pfs.project_id = p.id
WHERE p.parent_project_id IS NOT NULL
  AND p.is_master_project = false;

-- Grant access
GRANT SELECT ON v_site_jobs_summary TO authenticated;

-- =====================================================
-- MASTER PROJECT ROLLUP VIEW
-- =====================================================

CREATE OR REPLACE VIEW v_master_project_rollup AS
SELECT 
  p.id as master_project_id,
  p.project_number,
  p.name as project_name,
  p.customer_id,
  c.name as customer_name,
  p.status,
  p.contract_value_total,
  
  -- Site counts
  (SELECT COUNT(*) FROM projects WHERE parent_project_id = p.id) as total_sites,
  (SELECT COUNT(*) FROM projects WHERE parent_project_id = p.id AND status = 'completed') as sites_completed,
  (SELECT COUNT(*) FROM projects WHERE parent_project_id = p.id AND status = 'in_progress') as sites_in_progress,
  
  -- Unit-based completion
  CASE 
    WHEN (SELECT COUNT(*) FROM projects WHERE parent_project_id = p.id) > 0 THEN
      ((SELECT COUNT(*) FROM projects WHERE parent_project_id = p.id AND status = 'completed')::numeric / 
       (SELECT COUNT(*) FROM projects WHERE parent_project_id = p.id) * 100)
    ELSE 0
  END as percent_complete_units,
  
  -- Aggregated financials from all site jobs
  COALESCE((SELECT SUM(contract_value) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) as total_site_contract_value,
  COALESCE((SELECT SUM(billed_to_date) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) as total_billed,
  COALESCE((SELECT SUM(deposits_billed) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) as total_deposits,
  COALESCE((SELECT SUM(deposits_unreleased) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) as total_deposits_unreleased,
  COALESCE((SELECT SUM(revenue_recognized) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) as total_revenue_recognized,
  COALESCE((SELECT SUM(cost_to_date) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) as total_cost,
  COALESCE((SELECT SUM(gross_profit) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) as total_gross_profit,
  COALESCE((SELECT SUM(unbilled_amount) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) as total_unbilled,
  
  -- Calculated margin
  CASE 
    WHEN COALESCE((SELECT SUM(revenue_recognized) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) > 0 THEN
      (COALESCE((SELECT SUM(gross_profit) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) / 
       COALESCE((SELECT SUM(revenue_recognized) FROM v_site_jobs_summary WHERE master_project_id = p.id), 0) * 100)
    ELSE 0
  END as gross_margin_percent,
  
  -- Dates
  p.start_date,
  p.end_date,
  p.manager_id,
  pm.full_name as manager_name,
  p.created_at,
  p.updated_at

FROM projects p
JOIN customers c ON c.id = p.customer_id
LEFT JOIN profiles pm ON pm.id = p.manager_id
WHERE p.is_master_project = true;

-- Grant access
GRANT SELECT ON v_master_project_rollup TO authenticated;

-- =====================================================
-- HELPER FUNCTION: GET MASTER PROJECT PERCENT COMPLETE
-- =====================================================

CREATE OR REPLACE FUNCTION get_master_project_percent_complete(
  p_master_project_id uuid,
  p_method text DEFAULT 'units' -- 'units' or 'revenue'
)
RETURNS numeric AS $$
DECLARE
  v_percent numeric;
BEGIN
  IF p_method = 'units' THEN
    -- Unit-based: count of completed sites / total sites
    SELECT 
      CASE 
        WHEN COUNT(*) > 0 THEN
          (COUNT(*) FILTER (WHERE status = 'completed')::numeric / COUNT(*) * 100)
        ELSE 0
      END
    INTO v_percent
    FROM projects
    WHERE parent_project_id = p_master_project_id;
    
  ELSIF p_method = 'revenue' THEN
    -- Revenue-based: recognized revenue / contract value
    SELECT 
      CASE 
        WHEN COALESCE(p.contract_value_total, 0) > 0 THEN
          (COALESCE(SUM(pfs.revenue_recognized), 0) / p.contract_value_total * 100)
        ELSE 0
      END
    INTO v_percent
    FROM projects p
    LEFT JOIN projects child ON child.parent_project_id = p.id
    LEFT JOIN v_project_financial_summary pfs ON pfs.project_id = child.id
    WHERE p.id = p_master_project_id
    GROUP BY p.id, p.contract_value_total;
    
  ELSE
    v_percent := 0;
  END IF;
  
  RETURN COALESCE(v_percent, 0);
END;
$$ LANGUAGE plpgsql STABLE;
