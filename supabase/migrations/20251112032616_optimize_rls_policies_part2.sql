/*
  # Optimize RLS Policies - Part 2 (Accounting, Payroll, Time Tracking)

  Continuing RLS policy optimization by wrapping auth function calls in SELECT statements.

  ## Tables Optimized (Part 2)
  - time_logs
  - time_adjustments
  - chart_of_accounts
  - gl_entries
  - vendor_bills
  - bank_reconciliations
  - employee_pay_rates
  - payroll_runs
  - payroll_details
  - payroll_deductions
  - employee_deductions
  - accounting_settings
  - labor_rate_profile
*/

-- Drop and recreate optimized policies for TIME_LOGS
DROP POLICY IF EXISTS "Users can view own time logs" ON public.time_logs;
CREATE POLICY "Users can view own time logs"
  ON public.time_logs
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can create own time logs" ON public.time_logs;
CREATE POLICY "Users can create own time logs"
  ON public.time_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can update own time logs" ON public.time_logs;
CREATE POLICY "Users can update own time logs"
  ON public.time_logs
  FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admins can delete time logs" ON public.time_logs;
CREATE POLICY "Admins can delete time logs"
  ON public.time_logs
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for TIME_ADJUSTMENTS
DROP POLICY IF EXISTS "Managers can view time adjustments" ON public.time_adjustments;
CREATE POLICY "Managers can view time adjustments"
  ON public.time_adjustments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Managers can create time adjustments" ON public.time_adjustments;
CREATE POLICY "Managers can create time adjustments"
  ON public.time_adjustments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Managers can update time adjustments" ON public.time_adjustments;
CREATE POLICY "Managers can update time adjustments"
  ON public.time_adjustments
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Admins can delete time adjustments" ON public.time_adjustments;
CREATE POLICY "Admins can delete time adjustments"
  ON public.time_adjustments
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for CHART_OF_ACCOUNTS
DROP POLICY IF EXISTS "Admins can manage COA" ON public.chart_of_accounts;
CREATE POLICY "Admins can manage COA"
  ON public.chart_of_accounts
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for GL_ENTRIES
DROP POLICY IF EXISTS "Managers can view GL entries" ON public.gl_entries;
CREATE POLICY "Managers can view GL entries"
  ON public.gl_entries
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Managers can create GL entries" ON public.gl_entries;
CREATE POLICY "Managers can create GL entries"
  ON public.gl_entries
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Admins can update GL entries" ON public.gl_entries;
CREATE POLICY "Admins can update GL entries"
  ON public.gl_entries
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete GL entries" ON public.gl_entries;
CREATE POLICY "Admins can delete GL entries"
  ON public.gl_entries
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for VENDOR_BILLS
DROP POLICY IF EXISTS "Managers can view vendor bills" ON public.vendor_bills;
CREATE POLICY "Managers can view vendor bills"
  ON public.vendor_bills
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Managers can create vendor bills" ON public.vendor_bills;
CREATE POLICY "Managers can create vendor bills"
  ON public.vendor_bills
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Managers can update vendor bills" ON public.vendor_bills;
CREATE POLICY "Managers can update vendor bills"
  ON public.vendor_bills
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Admins can delete vendor bills" ON public.vendor_bills;
CREATE POLICY "Admins can delete vendor bills"
  ON public.vendor_bills
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for BANK_RECONCILIATIONS
DROP POLICY IF EXISTS "Managers can view bank reconciliations" ON public.bank_reconciliations;
CREATE POLICY "Managers can view bank reconciliations"
  ON public.bank_reconciliations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Managers can create bank reconciliations" ON public.bank_reconciliations;
CREATE POLICY "Managers can create bank reconciliations"
  ON public.bank_reconciliations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Managers can update bank reconciliations" ON public.bank_reconciliations;
CREATE POLICY "Managers can update bank reconciliations"
  ON public.bank_reconciliations
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Admins can delete bank reconciliations" ON public.bank_reconciliations;
CREATE POLICY "Admins can delete bank reconciliations"
  ON public.bank_reconciliations
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for EMPLOYEE_PAY_RATES
DROP POLICY IF EXISTS "Employees can view own pay rates" ON public.employee_pay_rates;
CREATE POLICY "Employees can view own pay rates"
  ON public.employee_pay_rates
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admins can manage pay rates" ON public.employee_pay_rates;
CREATE POLICY "Admins can manage pay rates"
  ON public.employee_pay_rates
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for PAYROLL_RUNS
DROP POLICY IF EXISTS "Admins can view payroll runs" ON public.payroll_runs;
CREATE POLICY "Admins can view payroll runs"
  ON public.payroll_runs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can manage payroll runs" ON public.payroll_runs;
CREATE POLICY "Admins can manage payroll runs"
  ON public.payroll_runs
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for PAYROLL_DETAILS
DROP POLICY IF EXISTS "Users can view own payroll details" ON public.payroll_details;
CREATE POLICY "Users can view own payroll details"
  ON public.payroll_details
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admins can manage payroll details" ON public.payroll_details;
CREATE POLICY "Admins can manage payroll details"
  ON public.payroll_details
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for PAYROLL_DEDUCTIONS
DROP POLICY IF EXISTS "Admins can manage deduction types" ON public.payroll_deductions;
CREATE POLICY "Admins can manage deduction types"
  ON public.payroll_deductions
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for EMPLOYEE_DEDUCTIONS
DROP POLICY IF EXISTS "Users can view own deductions" ON public.employee_deductions;
CREATE POLICY "Users can view own deductions"
  ON public.employee_deductions
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admins can manage employee deductions" ON public.employee_deductions;
CREATE POLICY "Admins can manage employee deductions"
  ON public.employee_deductions
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for ACCOUNTING_SETTINGS
DROP POLICY IF EXISTS "Only admins can update accounting settings" ON public.accounting_settings;
CREATE POLICY "Only admins can update accounting settings"
  ON public.accounting_settings
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Only admins can insert accounting settings" ON public.accounting_settings;
CREATE POLICY "Only admins can insert accounting settings"
  ON public.accounting_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Only admins can delete accounting settings" ON public.accounting_settings;
CREATE POLICY "Only admins can delete accounting settings"
  ON public.accounting_settings
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for LABOR_RATE_PROFILE
DROP POLICY IF EXISTS "Admins can manage labor rate profile" ON public.labor_rate_profile;
CREATE POLICY "Admins can manage labor rate profile"
  ON public.labor_rate_profile
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );
