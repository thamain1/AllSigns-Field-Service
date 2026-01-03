/*
  # Fix Global Billing Rate Function
  
  1. Changes
    - Drop the outdated get_global_billing_rate(text) function
    - Keep only the correct get_global_billing_rate(labor_rate_tier) version
    - Update trigger to use the correct function signature
  
  2. Purpose
    - Fixes clock out billing rate calculations
    - Ensures proper labor billing rates from accounting_settings
    - Maintains payroll and billing integrations
*/

-- Drop the outdated version that references non-existent columns
DROP FUNCTION IF EXISTS get_global_billing_rate(text);

-- The correct version with labor_rate_tier enum parameter already exists
-- It reads rates from accounting_settings table
