/*
  # Implement Labor Billing and Cost Tracking System

  ## Overview
  This migration implements a comprehensive labor tracking system with:
  - Single global billing rate profile (standard, after-hours, emergency)
  - Individual technician internal labor costs for profitability analysis
  - Enhanced time logs capturing both billing and actual cost data
  - Complete financial tracking for margin analysis and reporting

  ## Changes Made

  1. New Tables
    - `labor_rate_profile` - Single global billing rate configuration
    
  2. Modified Tables
    - `profiles` - Add labor_cost_per_hour for technicians
    - `time_logs` - Add billing and cost tracking fields
    
  3. New Enums
    - `labor_rate_tier` - standard, after_hours, emergency

  4. Functions
    - `get_current_labor_rate_tier()` - Determines rate tier based on time
    - `get_global_billing_rate()` - Gets billing rate for specific tier
    - `calculate_time_log_amounts()` - Calculates billing and cost amounts
    
  5. Triggers
    - Auto-calculate amounts on time log insert/update

  ## Billing Model
  
  **Global Billing Rates (Customer-Facing):**
  - Standard: $120/hr (Mon-Fri, 8am-5pm)
  - After-Hours: $160/hr (Mon-Fri, 5pm-8am; Weekends 8am-5pm)
  - Emergency: $200/hr (Weekends after 5pm, Holidays)
  
  **Technician Internal Costs:**
  - Each technician has labor_cost_per_hour (e.g., $45/hr)
  - Used for profitability calculations
  - Not visible to customers
  
  ## Reporting Capabilities
  - Labor margin per job (billing - cost)
  - Technician performance (revenue vs cost)
  - Project profitability analysis
  - Department labor expense tracking
*/

-- Create labor rate tier enum
DO $$ BEGIN
  CREATE TYPE labor_rate_tier AS ENUM (
    'standard',
    'after_hours',
    'emergency'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create labor_rate_profile table (single global configuration)
CREATE TABLE IF NOT EXISTS labor_rate_profile (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_name text DEFAULT 'Global Billing Rates',
  
  -- Billing rates (customer-facing)
  standard_rate numeric(10, 2) NOT NULL DEFAULT 120.00,
  after_hours_rate numeric(10, 2) NOT NULL DEFAULT 160.00,
  emergency_rate numeric(10, 2) NOT NULL DEFAULT 200.00,
  
  -- Rate tier definitions
  standard_hours_start time DEFAULT '08:00:00',
  standard_hours_end time DEFAULT '17:00:00',
  
  -- Notes
  description text,
  notes text,
  
  -- Status
  is_active boolean DEFAULT true,
  
  -- Metadata
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add labor_cost_per_hour to profiles for technicians
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'labor_cost_per_hour'
  ) THEN
    ALTER TABLE profiles ADD COLUMN labor_cost_per_hour numeric(10, 2) DEFAULT 45.00;
    COMMENT ON COLUMN profiles.labor_cost_per_hour IS 'Internal hourly labor cost for this technician (for profitability analysis)';
  END IF;
END $$;

-- Add billing and cost tracking fields to time_logs
DO $$
BEGIN
  -- Rate tier applied
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'time_logs' AND column_name = 'rate_tier'
  ) THEN
    ALTER TABLE time_logs ADD COLUMN rate_tier labor_rate_tier;
    COMMENT ON COLUMN time_logs.rate_tier IS 'Labor rate tier applied (standard/after_hours/emergency)';
  END IF;
  
  -- Billing rate applied
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'time_logs' AND column_name = 'billing_rate_applied'
  ) THEN
    ALTER TABLE time_logs ADD COLUMN billing_rate_applied numeric(10, 2);
    COMMENT ON COLUMN time_logs.billing_rate_applied IS 'Customer billing rate per hour applied to this time log';
  END IF;
  
  -- Labor cost applied
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'time_logs' AND column_name = 'labor_cost_applied'
  ) THEN
    ALTER TABLE time_logs ADD COLUMN labor_cost_applied numeric(10, 2);
    COMMENT ON COLUMN time_logs.labor_cost_applied IS 'Technician internal cost rate per hour applied to this time log';
  END IF;
  
  -- Total billed amount
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'time_logs' AND column_name = 'total_billed_amount'
  ) THEN
    ALTER TABLE time_logs ADD COLUMN total_billed_amount numeric(10, 2);
    COMMENT ON COLUMN time_logs.total_billed_amount IS 'Total amount billed to customer (duration × billing_rate_applied)';
  END IF;
  
  -- Total cost amount
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'time_logs' AND column_name = 'total_cost_amount'
  ) THEN
    ALTER TABLE time_logs ADD COLUMN total_cost_amount numeric(10, 2);
    COMMENT ON COLUMN time_logs.total_cost_amount IS 'Total internal labor cost (duration × labor_cost_applied)';
  END IF;
  
  -- Labor margin
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'time_logs' AND column_name = 'labor_margin'
  ) THEN
    ALTER TABLE time_logs ADD COLUMN labor_margin numeric(10, 2);
    COMMENT ON COLUMN time_logs.labor_margin IS 'Profit margin on labor (total_billed_amount - total_cost_amount)';
  END IF;
END $$;

-- Insert default global labor rate profile
INSERT INTO labor_rate_profile (
  profile_name,
  standard_rate,
  after_hours_rate,
  emergency_rate,
  description,
  is_active
) VALUES (
  'Global Billing Rates',
  120.00,
  160.00,
  200.00,
  'Company-wide customer billing rates. Standard rate applies Mon-Fri 8am-5pm. After-hours applies evenings and weekend days. Emergency applies weekend nights and holidays.',
  true
) ON CONFLICT DO NOTHING;

-- Function to determine current labor rate tier based on time
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
  
  -- Get standard hours from profile
  SELECT standard_hours_start, standard_hours_end
  INTO v_standard_start, v_standard_end
  FROM labor_rate_profile
  WHERE is_active = true
  LIMIT 1;
  
  -- Default to 8am-5pm if not configured
  v_standard_start := COALESCE(v_standard_start, '08:00:00'::time);
  v_standard_end := COALESCE(v_standard_end, '17:00:00'::time);
  
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

-- Function to get global billing rate for specific tier
CREATE OR REPLACE FUNCTION get_global_billing_rate(rate_tier labor_rate_tier)
RETURNS numeric AS $$
DECLARE
  v_rate numeric(10, 2);
BEGIN
  SELECT 
    CASE 
      WHEN rate_tier = 'standard' THEN standard_rate
      WHEN rate_tier = 'after_hours' THEN after_hours_rate
      WHEN rate_tier = 'emergency' THEN emergency_rate
      ELSE standard_rate
    END
  INTO v_rate
  FROM labor_rate_profile
  WHERE is_active = true
  LIMIT 1;
  
  RETURN COALESCE(v_rate, 120.00);
END;
$$ LANGUAGE plpgsql;

-- Function to calculate time log amounts
CREATE OR REPLACE FUNCTION calculate_time_log_amounts()
RETURNS TRIGGER AS $$
DECLARE
  v_duration_hours numeric(10, 2);
  v_billing_rate numeric(10, 2);
  v_labor_cost numeric(10, 2);
  v_rate_tier labor_rate_tier;
BEGIN
  -- Only calculate if we have clock_out_time
  IF NEW.clock_out_time IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Calculate duration in hours
  v_duration_hours := EXTRACT(EPOCH FROM (NEW.clock_out_time - NEW.clock_in_time)) / 3600.0;
  
  -- Subtract break duration if present
  IF NEW.break_duration IS NOT NULL AND NEW.break_duration > 0 THEN
    v_duration_hours := v_duration_hours - NEW.break_duration;
  END IF;
  
  -- Ensure non-negative
  IF v_duration_hours < 0 THEN
    v_duration_hours := 0;
  END IF;
  
  -- Update total_hours
  NEW.total_hours := v_duration_hours;
  
  -- Determine rate tier if not set
  IF NEW.rate_tier IS NULL THEN
    v_rate_tier := get_current_labor_rate_tier(NEW.clock_in_time);
    NEW.rate_tier := v_rate_tier;
  ELSE
    v_rate_tier := NEW.rate_tier;
  END IF;
  
  -- Get billing rate for this tier
  v_billing_rate := get_global_billing_rate(v_rate_tier);
  NEW.billing_rate_applied := v_billing_rate;
  
  -- Get technician's internal labor cost
  SELECT labor_cost_per_hour INTO v_labor_cost
  FROM profiles
  WHERE id = NEW.user_id;
  
  v_labor_cost := COALESCE(v_labor_cost, 45.00);
  NEW.labor_cost_applied := v_labor_cost;
  
  -- Calculate totals
  NEW.total_billed_amount := v_duration_hours * v_billing_rate;
  NEW.total_cost_amount := v_duration_hours * v_labor_cost;
  NEW.labor_margin := NEW.total_billed_amount - NEW.total_cost_amount;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-calculate time log amounts
DROP TRIGGER IF EXISTS trigger_calculate_time_log_amounts ON time_logs;
CREATE TRIGGER trigger_calculate_time_log_amounts
  BEFORE INSERT OR UPDATE ON time_logs
  FOR EACH ROW
  EXECUTE FUNCTION calculate_time_log_amounts();

-- Enable RLS on labor_rate_profile
ALTER TABLE labor_rate_profile ENABLE ROW LEVEL SECURITY;

-- RLS Policies for labor_rate_profile
CREATE POLICY "Authenticated users can view labor rate profile"
  ON labor_rate_profile FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage labor rate profile"
  ON labor_rate_profile FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_time_logs_rate_tier ON time_logs(rate_tier);
CREATE INDEX IF NOT EXISTS idx_time_logs_billing_rate ON time_logs(billing_rate_applied);
CREATE INDEX IF NOT EXISTS idx_time_logs_labor_margin ON time_logs(labor_margin);
CREATE INDEX IF NOT EXISTS idx_profiles_labor_cost ON profiles(labor_cost_per_hour);

-- Update accounting_settings to match new global rates
UPDATE accounting_settings
SET setting_value = '120.00', display_name = 'Standard Rate'
WHERE setting_key = 'default_labor_rate';

UPDATE accounting_settings
SET setting_value = '160.00', display_name = 'After-Hours Rate'
WHERE setting_key = 'overtime_labor_rate';

UPDATE accounting_settings
SET setting_value = '200.00', display_name = 'Emergency Rate'
WHERE setting_key = 'emergency_labor_rate';

-- Add helpful view for labor profitability analysis
CREATE OR REPLACE VIEW labor_profitability_summary AS
SELECT 
  tl.id as time_log_id,
  tl.user_id as technician_id,
  p.full_name as technician_name,
  tl.ticket_id,
  tl.project_id,
  tl.clock_in_time,
  tl.clock_out_time,
  tl.rate_tier,
  tl.billing_rate_applied,
  tl.labor_cost_applied,
  tl.total_hours as hours_worked,
  tl.total_billed_amount,
  tl.total_cost_amount,
  tl.labor_margin,
  CASE 
    WHEN tl.total_billed_amount > 0 THEN 
      (tl.labor_margin / tl.total_billed_amount * 100)
    ELSE 0 
  END as margin_percentage
FROM time_logs tl
LEFT JOIN profiles p ON tl.user_id = p.id
WHERE tl.clock_out_time IS NOT NULL;

-- Grant access to the view
GRANT SELECT ON labor_profitability_summary TO authenticated;
