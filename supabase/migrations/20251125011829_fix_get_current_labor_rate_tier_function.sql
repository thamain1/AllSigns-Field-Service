/*
  # Fix Labor Rate Tier Function
  
  1. Changes
    - Drop the outdated get_current_labor_rate_tier(date) function
    - Keep only the correct get_current_labor_rate_tier(timestamptz) version
    - This ensures time log triggers use the right function signature
  
  2. Purpose
    - Fixes clock out calculations
    - Ensures proper labor rate tier determination
    - Maintains payroll and billing integrations
*/

-- Drop the outdated version that references non-existent columns
DROP FUNCTION IF EXISTS get_current_labor_rate_tier(date);

-- The correct version with timestamp parameter already exists and works correctly
-- It determines rate based on time of day and day of week
-- Returns: 'standard', 'after_hours', or 'emergency'
