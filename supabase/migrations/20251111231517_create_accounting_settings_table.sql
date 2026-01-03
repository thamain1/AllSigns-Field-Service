/*
  # Accounting Settings Configuration

  ## Overview
  Creates a centralized settings table for managing accounting configurations
  such as labor rates, tax rates, payment terms, and other financial settings.

  ## 1. New Tables
    - `accounting_settings`
      - `id` (uuid, primary key)
      - `setting_key` (text, unique) - The configuration key
      - `setting_value` (text) - The value stored as text
      - `setting_type` (enum) - Data type for validation
      - `display_name` (text) - Human-readable name
      - `description` (text) - Explanation of the setting
      - `category` (text) - Grouping for settings
      - `display_order` (integer) - Sort order in UI
      - `is_editable` (boolean) - Can be changed by users
      - `updated_by` (uuid) - User who last updated
      - `created_at`, `updated_at` (timestamptz)

  ## 2. Setting Types
    - number: Numeric values (rates, percentages)
    - text: String values (terms, descriptions)
    - boolean: True/false values
    - date: Date values

  ## 3. Security
    - RLS enabled on accounting_settings table
    - Only authenticated users can read settings
    - Only admins can update settings

  ## 4. Initial Settings
    - default_labor_rate: $85.00/hour
    - default_tax_rate: 8.5%
    - default_payment_terms: Net 30
    - invoice_due_days: 30
    - travel_charge_rate: $50.00
    - overtime_labor_rate: $127.50/hour
    - emergency_labor_rate: $170.00/hour
*/

-- Create enum for setting types
DO $$ BEGIN
  CREATE TYPE setting_type AS ENUM ('number', 'text', 'boolean', 'date');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create accounting_settings table
CREATE TABLE IF NOT EXISTS accounting_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key text UNIQUE NOT NULL,
  setting_value text NOT NULL,
  setting_type setting_type NOT NULL DEFAULT 'text',
  display_name text NOT NULL,
  description text,
  category text NOT NULL DEFAULT 'general',
  display_order integer NOT NULL DEFAULT 0,
  is_editable boolean NOT NULL DEFAULT true,
  updated_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE accounting_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Authenticated users can read accounting settings"
  ON accounting_settings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can update accounting settings"
  ON accounting_settings FOR UPDATE
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

CREATE POLICY "Only admins can insert accounting settings"
  ON accounting_settings FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Only admins can delete accounting settings"
  ON accounting_settings FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_accounting_settings_key ON accounting_settings(setting_key);
CREATE INDEX IF NOT EXISTS idx_accounting_settings_category ON accounting_settings(category);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_accounting_settings_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  NEW.updated_by = auth.uid();
  RETURN NEW;
END;
$$;

-- Trigger to auto-update timestamp
DROP TRIGGER IF EXISTS accounting_settings_updated_at ON accounting_settings;

CREATE TRIGGER accounting_settings_updated_at
  BEFORE UPDATE ON accounting_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_accounting_settings_timestamp();

-- Insert default settings
INSERT INTO accounting_settings (setting_key, setting_value, setting_type, display_name, description, category, display_order, is_editable)
VALUES
  ('default_labor_rate', '85.00', 'number', 'Default Labor Rate', 'Standard hourly rate for labor charges ($/hour)', 'labor', 1, true),
  ('overtime_labor_rate', '127.50', 'number', 'Overtime Labor Rate', 'Overtime hourly rate (1.5x standard rate)', 'labor', 2, true),
  ('emergency_labor_rate', '170.00', 'number', 'Emergency Labor Rate', 'Emergency/after-hours hourly rate (2x standard rate)', 'labor', 3, true),
  ('travel_charge_rate', '50.00', 'number', 'Travel Charge', 'Standard travel fee for service calls', 'labor', 4, true),
  ('default_tax_rate', '8.5', 'number', 'Default Tax Rate', 'Sales tax percentage applied to invoices', 'tax', 10, true),
  ('default_payment_terms', 'Net 30', 'text', 'Default Payment Terms', 'Standard payment terms for invoices', 'invoicing', 20, true),
  ('invoice_due_days', '30', 'number', 'Invoice Due Days', 'Number of days until invoice is due', 'invoicing', 21, true),
  ('late_payment_fee_percent', '1.5', 'number', 'Late Payment Fee', 'Monthly late payment fee percentage', 'invoicing', 22, true),
  ('discount_threshold', '1000.00', 'number', 'Volume Discount Threshold', 'Minimum invoice amount for volume discounts', 'invoicing', 23, true),
  ('discount_percentage', '5.0', 'number', 'Volume Discount Percentage', 'Discount percentage for large invoices', 'invoicing', 24, true)
ON CONFLICT (setting_key) DO NOTHING;

-- Helper function to get setting value
CREATE OR REPLACE FUNCTION get_accounting_setting(p_key text, p_default text DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_value text;
BEGIN
  SELECT setting_value INTO v_value
  FROM accounting_settings
  WHERE setting_key = p_key;
  
  RETURN COALESCE(v_value, p_default);
END;
$$;

-- Helper function to get numeric setting value
CREATE OR REPLACE FUNCTION get_accounting_setting_numeric(p_key text, p_default numeric DEFAULT NULL)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_value text;
BEGIN
  SELECT setting_value INTO v_value
  FROM accounting_settings
  WHERE setting_key = p_key;
  
  RETURN COALESCE(v_value::numeric, p_default);
END;
$$;

GRANT EXECUTE ON FUNCTION get_accounting_setting(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_accounting_setting_numeric(text, numeric) TO authenticated;
