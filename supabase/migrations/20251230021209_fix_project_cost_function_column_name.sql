/*
  # Fix get_project_cost_to_date Function Column Name

  1. Changes
    - Fix get_project_cost_to_date to use correct time_logs column names
    - Use total_cost_amount instead of billing_amount for actual labor costs
    - This fixes the v_master_project_rollup view which depends on this function

  2. Notes
    - The time_logs table has total_cost_amount and total_billed_amount columns
    - billing_amount column never existed, causing view queries to fail
*/

CREATE OR REPLACE FUNCTION get_project_cost_to_date(p_project_id uuid)
RETURNS numeric AS $$
DECLARE
  v_labor_cost numeric := 0;
  v_parts_cost numeric := 0;
  v_other_cost numeric := 0;
BEGIN
  -- Get labor costs from time logs (use total_cost_amount, not billing_amount)
  SELECT COALESCE(SUM(tl.total_cost_amount), 0)
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
