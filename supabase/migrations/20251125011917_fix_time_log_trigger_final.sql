/*
  # Final Fix for Time Log Trigger
  
  1. Changes
    - Update calculate_time_log_amounts() to use correct function signatures
    - Remove text cast from get_global_billing_rate call
    - Use labor_rate_tier enum type directly
  
  2. Purpose
    - Completes the clock in/out fix for technicians
    - Ensures all billing and cost calculations work correctly
    - Maintains all existing payroll, accounting, and reporting integrations
*/

CREATE OR REPLACE FUNCTION calculate_time_log_amounts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  hours_worked numeric;
  user_labor_cost numeric;
  rate_tier labor_rate_tier;
  global_rate numeric;
BEGIN
  -- Only calculate when both clock_in_time and clock_out_time are set
  IF NEW.clock_out_time IS NOT NULL AND NEW.clock_in_time IS NOT NULL THEN
    -- Calculate hours worked
    hours_worked := EXTRACT(EPOCH FROM (NEW.clock_out_time - NEW.clock_in_time)) / 3600.0;
    
    -- Get user's labor cost per hour
    SELECT labor_cost_per_hour 
    INTO user_labor_cost 
    FROM profiles 
    WHERE id = NEW.user_id;
    
    -- Calculate labor cost (what it costs the company)
    NEW.labor_cost_applied := hours_worked * COALESCE(user_labor_cost, 25.00);
    
    -- Get the rate tier for this time period
    rate_tier := get_current_labor_rate_tier(NEW.clock_in_time);
    NEW.rate_tier := rate_tier;
    
    -- Get the billing rate for this tier (using enum type, not text)
    global_rate := get_global_billing_rate(rate_tier);
    NEW.billing_rate_applied := global_rate;
    
    -- Calculate total billed amount (what customer pays)
    NEW.total_billed_amount := hours_worked * global_rate;
    
    -- Calculate total cost amount
    NEW.total_cost_amount := NEW.labor_cost_applied;
    
    -- Calculate labor margin (profit)
    NEW.labor_margin := NEW.total_billed_amount - NEW.total_cost_amount;
  END IF;
  
  RETURN NEW;
END;
$$;
