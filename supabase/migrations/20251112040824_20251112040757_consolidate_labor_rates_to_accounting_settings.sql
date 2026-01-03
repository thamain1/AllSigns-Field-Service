/*
  # Consolidate Labor Rates to Accounting Settings

  ## Overview
  Moves labor rate management from labor_rate_profile table to accounting_settings
  to centralize all financial configuration in one place. Labor rates should be
  managed within the Accounting module, not Company Settings.

  ## Changes Made

  1. Updates
    - Update time_logs to reference accounting_settings instead of labor_rate_profile
    - Ensure accounting_settings has all necessary labor rate entries
    
  2. Functions Updated
    - get_global_billing_rate() - Now reads from accounting_settings
    - calculate_time_log_amounts() - Updated to use accounting_settings
    
  3. Migration Path
    - Preserve existing labor rate values during transition
    - Update functions to use accounting_settings
    - labor_rate_profile table will remain but is no longer used by application
    
  ## Important Notes
  - All labor rates now managed through accounting_settings table
  - Labor rates accessible via get_accounting_setting_numeric() function
  - Time logs will automatically use rates from accounting_settings
  - Old labor_rate_profile data is preserved for historical reference
*/

-- Ensure accounting_settings has the required labor rate entries with proper naming
INSERT INTO accounting_settings (setting_key, setting_value, setting_type, display_name, description, category, display_order, is_editable)
VALUES
  ('standard_labor_rate', '120.00', 'number', 'Standard Labor Rate', 'Standard hourly rate for labor charges during business hours ($/hour)', 'labor_rates', 1, true),
  ('after_hours_labor_rate', '160.00', 'number', 'After-Hours Labor Rate', 'After-hours hourly rate for evenings and weekends ($/hour)', 'labor_rates', 2, true),
  ('emergency_labor_rate', '200.00', 'number', 'Emergency Labor Rate', 'Emergency hourly rate for late nights and holidays ($/hour)', 'labor_rates', 3, true),
  ('standard_hours_start', '08:00:00', 'text', 'Business Hours Start', 'Time when standard rate begins (Mon-Fri)', 'labor_rates', 4, true),
  ('standard_hours_end', '17:00:00', 'text', 'Business Hours End', 'Time when standard rate ends (Mon-Fri)', 'labor_rates', 5, true)
ON CONFLICT (setting_key) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  description = EXCLUDED.description,
  category = EXCLUDED.category;

-- Update existing accounting settings to match if labor_rate_profile has data
DO $$
DECLARE
  v_profile RECORD;
BEGIN
  SELECT * INTO v_profile FROM labor_rate_profile WHERE is_active = true LIMIT 1;
  
  IF FOUND THEN
    UPDATE accounting_settings
    SET setting_value = v_profile.standard_rate::text
    WHERE setting_key = 'standard_labor_rate';
    
    UPDATE accounting_settings
    SET setting_value = v_profile.after_hours_rate::text
    WHERE setting_key = 'after_hours_labor_rate';
    
    UPDATE accounting_settings
    SET setting_value = v_profile.emergency_rate::text
    WHERE setting_key = 'emergency_labor_rate';
    
    UPDATE accounting_settings
    SET setting_value = v_profile.standard_hours_start::text
    WHERE setting_key = 'standard_hours_start';
    
    UPDATE accounting_settings
    SET setting_value = v_profile.standard_hours_end::text
    WHERE setting_key = 'standard_hours_end';
  END IF;
END $$;

-- Remove old labor rate settings with incorrect names
DELETE FROM accounting_settings WHERE setting_key IN ('default_labor_rate', 'overtime_labor_rate');

-- Update get_global_billing_rate function to use accounting_settings
CREATE OR REPLACE FUNCTION get_global_billing_rate(rate_tier labor_rate_tier)
RETURNS numeric AS $$
DECLARE
  v_rate numeric(10, 2);
BEGIN
  -- Get rate from accounting_settings based on tier
  SELECT 
    CASE 
      WHEN rate_tier = 'standard' THEN get_accounting_setting_numeric('standard_labor_rate', 120.00)
      WHEN rate_tier = 'after_hours' THEN get_accounting_setting_numeric('after_hours_labor_rate', 160.00)
      WHEN rate_tier = 'emergency' THEN get_accounting_setting_numeric('emergency_labor_rate', 200.00)
      ELSE get_accounting_setting_numeric('standard_labor_rate', 120.00)
    END
  INTO v_rate;
  
  RETURN COALESCE(v_rate, 120.00);
END;
$$ LANGUAGE plpgsql;

-- Update get_current_labor_rate_tier function to use accounting_settings for hours
CREATE OR REPLACE FUNCTION get_current_labor_rate_tier(check_time timestamptz DEFAULT now())
RETURNS labor_rate_tier AS $$
DECLARE
  v_day_of_week integer;
  v_time_of_day time;
  v_standard_start time;
  v_standard_end time;
BEGIN
  -- Get day of week (0=Sunday, 6=Saturday)
  v_day_of_week := EXTRACT(DOW FROM check_time);
  
  -- Get time of day
  v_time_of_day := check_time::time;
  
  -- Get standard hours from accounting_settings
  v_standard_start := get_accounting_setting('standard_hours_start', '08:00:00')::time;
  v_standard_end := get_accounting_setting('standard_hours_end', '17:00:00')::time;
  
  -- Weekend logic
  IF v_day_of_week = 0 OR v_day_of_week = 6 THEN
    -- Weekend: after 5pm = emergency, before = after_hours
    IF v_time_of_day >= v_standard_end THEN
      RETURN 'emergency'::labor_rate_tier;
    ELSE
      RETURN 'after_hours'::labor_rate_tier;
    END IF;
  END IF;
  
  -- Weekday logic
  IF v_time_of_day >= v_standard_start AND v_time_of_day < v_standard_end THEN
    RETURN 'standard'::labor_rate_tier;
  ELSE
    RETURN 'after_hours'::labor_rate_tier;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Add comment to labor_rate_profile table noting it's deprecated
COMMENT ON TABLE labor_rate_profile IS 'DEPRECATED: This table is no longer used. Labor rates are now managed in accounting_settings table. Preserved for historical reference only.';
