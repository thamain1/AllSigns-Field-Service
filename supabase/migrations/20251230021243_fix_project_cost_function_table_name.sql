/*
  # Fix get_project_cost_to_date Function Table Name

  1. Changes
    - Fix get_project_cost_to_date to use correct parts table name
    - Use parts_usage instead of ticket_parts
    - This fixes the v_master_project_rollup view which depends on this function

  2. Notes
    - The correct table name is parts_usage, not ticket_parts
*/

CREATE OR REPLACE FUNCTION get_project_cost_to_date(p_project_id uuid)
RETURNS numeric AS $$
DECLARE
  v_labor_cost numeric := 0;
  v_parts_cost numeric := 0;
  v_other_cost numeric := 0;
BEGIN
  -- Get labor costs from time logs (use total_cost_amount)
  SELECT COALESCE(SUM(tl.total_cost_amount), 0)
  INTO v_labor_cost
  FROM time_logs tl
  WHERE tl.project_id = p_project_id;
  
  -- Get parts costs from parts usage linked to project tickets
  SELECT COALESCE(SUM(pu.quantity * pu.cost_per_unit), 0)
  INTO v_parts_cost
  FROM parts_usage pu
  JOIN tickets t ON t.id = pu.ticket_id
  WHERE t.project_id = p_project_id;
  
  -- Could add other cost sources here (POs, equipment, etc.)
  
  RETURN v_labor_cost + v_parts_cost + v_other_cost;
END;
$$ LANGUAGE plpgsql STABLE;
