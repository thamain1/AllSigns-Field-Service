/*
  # Payroll Schema

  ## Overview
  This migration creates the payroll infrastructure for automating technician and staff payroll
  based on tracked time, with full integration into the accounting system.

  ## 1. New Tables

  ### Employee Pay Rates
    - `employee_pay_rates` - Pay rate configuration per employee
      - `id` (uuid, primary key)
      - `user_id` (uuid) - Foreign key to profiles
      - `hourly_rate` (decimal) - Regular hourly rate
      - `overtime_rate` (decimal) - Overtime hourly rate
      - `overtime_threshold` (decimal) - Hours before overtime kicks in (e.g., 40)
      - `salary_amount` (decimal, nullable) - For salaried employees
      - `pay_frequency` (enum) - weekly, bi_weekly, semi_monthly, monthly
      - `effective_date` (date) - When this rate becomes effective
      - `end_date` (date, nullable) - When this rate ends
      - `is_active` (boolean) - Current rate
      - `bonus_eligible` (boolean) - Eligible for bonuses
      - `per_diem_rate` (decimal) - Per day travel allowance
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Payroll Runs
    - `payroll_runs` - Payroll processing periods
      - `id` (uuid, primary key)
      - `run_number` (text, unique) - Payroll run identifier
      - `period_start_date` (date) - Pay period start
      - `period_end_date` (date) - Pay period end
      - `pay_date` (date) - Actual payment date
      - `status` (enum) - draft, processing, approved, paid, cancelled
      - `total_gross_pay` (decimal) - Total gross for all employees
      - `total_deductions` (decimal) - Total deductions
      - `total_net_pay` (decimal) - Total net pay
      - `employee_count` (integer) - Number of employees paid
      - `gl_posted` (boolean) - Posted to general ledger
      - `notes` (text) - Payroll run notes
      - `processed_by` (uuid) - Foreign key to profiles
      - `approved_by` (uuid, nullable) - Foreign key to profiles
      - `approved_at` (timestamptz, nullable)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Payroll Details
    - `payroll_details` - Individual employee payroll for each run
      - `id` (uuid, primary key)
      - `payroll_run_id` (uuid) - Foreign key to payroll_runs
      - `user_id` (uuid) - Foreign key to profiles (employee)
      - `regular_hours` (decimal) - Regular hours worked
      - `overtime_hours` (decimal) - Overtime hours worked
      - `bonus_hours` (decimal) - Bonus or adjustment hours
      - `regular_pay` (decimal) - Pay for regular hours
      - `overtime_pay` (decimal) - Pay for overtime hours
      - `bonus_pay` (decimal) - Bonus payments
      - `per_diem_pay` (decimal) - Travel per diem
      - `gross_pay` (decimal) - Total gross pay
      - `federal_tax` (decimal) - Federal tax withheld
      - `state_tax` (decimal) - State tax withheld
      - `social_security` (decimal) - SS tax
      - `medicare` (decimal) - Medicare tax
      - `other_deductions` (decimal) - Health insurance, 401k, etc.
      - `total_deductions` (decimal) - Sum of all deductions
      - `net_pay` (decimal) - Take-home pay
      - `notes` (text) - Employee-specific notes
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ### Payroll Deductions
    - `payroll_deductions` - Configurable deduction types
      - `id` (uuid, primary key)
      - `deduction_name` (text) - Name of deduction
      - `deduction_type` (enum) - tax, insurance, retirement, garnishment, other
      - `is_pre_tax` (boolean) - Deducted before tax calculation
      - `calculation_method` (enum) - fixed_amount, percentage
      - `default_amount` (decimal) - Default deduction amount or %
      - `is_active` (boolean) - Active status
      - `created_at` (timestamptz)

  ### Employee Deductions
    - `employee_deductions` - Per-employee deduction configuration
      - `id` (uuid, primary key)
      - `user_id` (uuid) - Foreign key to profiles
      - `deduction_id` (uuid) - Foreign key to payroll_deductions
      - `amount` (decimal) - Override amount
      - `is_active` (boolean) - Active for this employee
      - `created_at` (timestamptz)

  ## 2. Integration Points
    - Pull hours from time_logs table
    - Post payroll journal entries to gl_entries
    - Track labor costs per ticket and project
    - Generate pay stubs and reports

  ## 3. Security
    - Enable RLS on all tables
    - Admin-only access to payroll data
    - Employees can view their own pay history

  ## 4. Indexes
    - User ID for employee payroll history
    - Payroll run dates for period queries
    - Status for workflow management
*/

-- Create pay frequency enum
DO $$ BEGIN
  CREATE TYPE pay_frequency AS ENUM ('weekly', 'bi_weekly', 'semi_monthly', 'monthly');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create payroll run status enum
DO $$ BEGIN
  CREATE TYPE payroll_run_status AS ENUM ('draft', 'processing', 'approved', 'paid', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create deduction type enum
DO $$ BEGIN
  CREATE TYPE deduction_type AS ENUM ('tax', 'insurance', 'retirement', 'garnishment', 'other');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create calculation method enum
DO $$ BEGIN
  CREATE TYPE calculation_method AS ENUM ('fixed_amount', 'percentage');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Create employee pay rates table
CREATE TABLE IF NOT EXISTS employee_pay_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  hourly_rate decimal(10,2) DEFAULT 0,
  overtime_rate decimal(10,2) DEFAULT 0,
  overtime_threshold decimal(10,2) DEFAULT 40,
  salary_amount decimal(10,2),
  pay_frequency pay_frequency DEFAULT 'bi_weekly',
  effective_date date NOT NULL DEFAULT CURRENT_DATE,
  end_date date,
  is_active boolean DEFAULT true,
  bonus_eligible boolean DEFAULT false,
  per_diem_rate decimal(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create payroll runs table
CREATE TABLE IF NOT EXISTS payroll_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_number text UNIQUE NOT NULL,
  period_start_date date NOT NULL,
  period_end_date date NOT NULL,
  pay_date date NOT NULL,
  status payroll_run_status DEFAULT 'draft',
  total_gross_pay decimal(10,2) DEFAULT 0,
  total_deductions decimal(10,2) DEFAULT 0,
  total_net_pay decimal(10,2) DEFAULT 0,
  employee_count integer DEFAULT 0,
  gl_posted boolean DEFAULT false,
  notes text,
  processed_by uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  approved_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  approved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create payroll details table
CREATE TABLE IF NOT EXISTS payroll_details (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payroll_run_id uuid NOT NULL REFERENCES payroll_runs(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  regular_hours decimal(10,2) DEFAULT 0,
  overtime_hours decimal(10,2) DEFAULT 0,
  bonus_hours decimal(10,2) DEFAULT 0,
  regular_pay decimal(10,2) DEFAULT 0,
  overtime_pay decimal(10,2) DEFAULT 0,
  bonus_pay decimal(10,2) DEFAULT 0,
  per_diem_pay decimal(10,2) DEFAULT 0,
  gross_pay decimal(10,2) DEFAULT 0,
  federal_tax decimal(10,2) DEFAULT 0,
  state_tax decimal(10,2) DEFAULT 0,
  social_security decimal(10,2) DEFAULT 0,
  medicare decimal(10,2) DEFAULT 0,
  other_deductions decimal(10,2) DEFAULT 0,
  total_deductions decimal(10,2) DEFAULT 0,
  net_pay decimal(10,2) DEFAULT 0,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(payroll_run_id, user_id)
);

-- Create payroll deductions table
CREATE TABLE IF NOT EXISTS payroll_deductions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deduction_name text NOT NULL,
  deduction_type deduction_type NOT NULL,
  is_pre_tax boolean DEFAULT false,
  calculation_method calculation_method DEFAULT 'fixed_amount',
  default_amount decimal(10,2) DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Create employee deductions table
CREATE TABLE IF NOT EXISTS employee_deductions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  deduction_id uuid NOT NULL REFERENCES payroll_deductions(id) ON DELETE CASCADE,
  amount decimal(10,2) DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, deduction_id)
);

-- Insert default deduction types
INSERT INTO payroll_deductions (deduction_name, deduction_type, calculation_method, default_amount, is_active) VALUES
('Federal Income Tax', 'tax', 'percentage', 12.00, true),
('State Income Tax', 'tax', 'percentage', 5.00, true),
('Social Security', 'tax', 'percentage', 6.20, true),
('Medicare', 'tax', 'percentage', 1.45, true),
('Health Insurance', 'insurance', 'fixed_amount', 150.00, true),
('Dental Insurance', 'insurance', 'fixed_amount', 25.00, true),
('401(k) Contribution', 'retirement', 'percentage', 5.00, true)
ON CONFLICT DO NOTHING;

-- Enable RLS
ALTER TABLE employee_pay_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_deductions ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_deductions ENABLE ROW LEVEL SECURITY;

-- Pay rates policies - admins manage, employees can view own
CREATE POLICY "Employees can view own pay rates"
  ON employee_pay_rates FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

CREATE POLICY "Admins can manage pay rates"
  ON employee_pay_rates FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Payroll runs policies - admin only
CREATE POLICY "Admins can view payroll runs"
  ON payroll_runs FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

CREATE POLICY "Admins can manage payroll runs"
  ON payroll_runs FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Payroll details policies - employees can view own, admins can view all
CREATE POLICY "Users can view own payroll details"
  ON payroll_details FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

CREATE POLICY "Admins can manage payroll details"
  ON payroll_details FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Deduction type policies - admin manage, all can view
CREATE POLICY "All users can view deduction types"
  ON payroll_deductions FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage deduction types"
  ON payroll_deductions FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Employee deductions policies - employees view own, admins manage
CREATE POLICY "Users can view own deductions"
  ON employee_deductions FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

CREATE POLICY "Admins can manage employee deductions"
  ON employee_deductions FOR ALL
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pay_rates_user ON employee_pay_rates(user_id);
CREATE INDEX IF NOT EXISTS idx_pay_rates_effective ON employee_pay_rates(effective_date);
CREATE INDEX IF NOT EXISTS idx_payroll_runs_number ON payroll_runs(run_number);
CREATE INDEX IF NOT EXISTS idx_payroll_runs_dates ON payroll_runs(period_start_date, period_end_date);
CREATE INDEX IF NOT EXISTS idx_payroll_runs_status ON payroll_runs(status);
CREATE INDEX IF NOT EXISTS idx_payroll_details_run ON payroll_details(payroll_run_id);
CREATE INDEX IF NOT EXISTS idx_payroll_details_user ON payroll_details(user_id);
CREATE INDEX IF NOT EXISTS idx_employee_deductions_user ON employee_deductions(user_id);