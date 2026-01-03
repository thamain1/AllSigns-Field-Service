/*
  # Enhance Vendors Table and Create Vendor Management Module

  ## Changes to Existing Tables
  - Enhance vendors table with additional fields for comprehensive vendor management
  
  ## New Tables
  - vendor_categories - Vendor categorization
  - vendor_contacts - Multiple contacts per vendor
  - vendor_contracts - Contract tracking
  - vendor_part_mappings - Link vendors to parts
  - vendor_performance_metrics - Performance tracking
  - vendor_payments - Payment history
  - vendor_audit_log - Audit trail
*/

-- Create vendor categories table
CREATE TABLE IF NOT EXISTS public.vendor_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enhance existing vendors table with new columns
DO $$
BEGIN
  -- Add new columns if they don't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'legal_name') THEN
    ALTER TABLE public.vendors ADD COLUMN legal_name text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'display_name') THEN
    ALTER TABLE public.vendors ADD COLUMN display_name text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'tax_id') THEN
    ALTER TABLE public.vendors ADD COLUMN tax_id text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'address_line1') THEN
    ALTER TABLE public.vendors ADD COLUMN address_line1 text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'address_line2') THEN
    ALTER TABLE public.vendors ADD COLUMN address_line2 text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'postal_code') THEN
    ALTER TABLE public.vendors ADD COLUMN postal_code text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'country') THEN
    ALTER TABLE public.vendors ADD COLUMN country text DEFAULT 'USA';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'primary_phone') THEN
    ALTER TABLE public.vendors ADD COLUMN primary_phone text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'primary_email') THEN
    ALTER TABLE public.vendors ADD COLUMN primary_email text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'payment_method') THEN
    ALTER TABLE public.vendors ADD COLUMN payment_method text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'currency') THEN
    ALTER TABLE public.vendors ADD COLUMN currency text DEFAULT 'USD';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'credit_limit') THEN
    ALTER TABLE public.vendors ADD COLUMN credit_limit numeric(12,2);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'bank_name') THEN
    ALTER TABLE public.vendors ADD COLUMN bank_name text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'bank_account_last4') THEN
    ALTER TABLE public.vendors ADD COLUMN bank_account_last4 text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'bank_routing_number') THEN
    ALTER TABLE public.vendors ADD COLUMN bank_routing_number text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'preferred_vendor') THEN
    ALTER TABLE public.vendors ADD COLUMN preferred_vendor boolean DEFAULT false;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'standard_lead_time_days') THEN
    ALTER TABLE public.vendors ADD COLUMN standard_lead_time_days integer DEFAULT 7;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'minimum_order_amount') THEN
    ALTER TABLE public.vendors ADD COLUMN minimum_order_amount numeric(10,2);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'status') THEN
    ALTER TABLE public.vendors ADD COLUMN status text DEFAULT 'active';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'rating') THEN
    ALTER TABLE public.vendors ADD COLUMN rating numeric(3,2);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'onboarding_status') THEN
    ALTER TABLE public.vendors ADD COLUMN onboarding_status text DEFAULT 'completed';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'w9_verified') THEN
    ALTER TABLE public.vendors ADD COLUMN w9_verified boolean DEFAULT false;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'bank_verified') THEN
    ALTER TABLE public.vendors ADD COLUMN bank_verified boolean DEFAULT false;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'approved_by') THEN
    ALTER TABLE public.vendors ADD COLUMN approved_by uuid REFERENCES public.profiles(id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'approved_at') THEN
    ALTER TABLE public.vendors ADD COLUMN approved_at timestamptz;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'category_ids') THEN
    ALTER TABLE public.vendors ADD COLUMN category_ids uuid[];
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'internal_notes') THEN
    ALTER TABLE public.vendors ADD COLUMN internal_notes text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vendors' AND column_name = 'created_by') THEN
    ALTER TABLE public.vendors ADD COLUMN created_by uuid REFERENCES public.profiles(id);
  END IF;
END $$;

-- Vendor Contacts
CREATE TABLE IF NOT EXISTS public.vendor_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  name text NOT NULL,
  title text,
  role text,
  phone text,
  mobile text,
  email text,
  is_primary boolean DEFAULT false,
  is_billing_contact boolean DEFAULT false,
  is_shipping_contact boolean DEFAULT false,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Vendor Contracts
CREATE TABLE IF NOT EXISTS public.vendor_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  contract_number text,
  contract_type text,
  start_date date NOT NULL,
  end_date date,
  renewal_date date,
  auto_renew boolean DEFAULT false,
  contract_value numeric(12,2),
  document_url text,
  document_name text,
  terms_and_conditions text,
  sla_terms text,
  payment_terms text,
  status text DEFAULT 'draft',
  renewal_reminder_days integer DEFAULT 30,
  renewal_reminder_sent boolean DEFAULT false,
  version integer DEFAULT 1,
  parent_contract_id uuid REFERENCES public.vendor_contracts(id),
  notes text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Vendor Part Mappings
CREATE TABLE IF NOT EXISTS public.vendor_part_mappings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  part_id uuid NOT NULL REFERENCES public.parts(id) ON DELETE CASCADE,
  vendor_part_number text,
  vendor_part_description text,
  standard_cost numeric(10,2),
  last_cost numeric(10,2),
  last_purchase_date date,
  lead_time_days integer DEFAULT 7,
  minimum_order_qty integer DEFAULT 1,
  is_preferred_vendor boolean DEFAULT false,
  is_discontinued boolean DEFAULT false,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(vendor_id, part_id)
);

-- Vendor Performance Metrics
CREATE TABLE IF NOT EXISTS public.vendor_performance_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  metric_type text NOT NULL,
  metric_value numeric(10,2) NOT NULL,
  metric_target numeric(10,2),
  period_start date NOT NULL,
  period_end date NOT NULL,
  sample_size integer,
  notes text,
  recorded_by uuid REFERENCES public.profiles(id),
  recorded_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Vendor Payments
CREATE TABLE IF NOT EXISTS public.vendor_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE RESTRICT,
  payment_number text UNIQUE,
  payment_date date NOT NULL,
  payment_amount numeric(12,2) NOT NULL,
  payment_method text,
  vendor_bill_id uuid REFERENCES public.vendor_bills(id),
  purchase_order_id uuid REFERENCES public.purchase_orders(id),
  check_number text,
  transaction_reference text,
  description text,
  notes text,
  status text DEFAULT 'pending',
  processed_by uuid REFERENCES public.profiles(id),
  processed_at timestamptz,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Vendor Audit Log
CREATE TABLE IF NOT EXISTS public.vendor_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
  action_type text NOT NULL,
  field_name text,
  old_value text,
  new_value text,
  description text,
  performed_by uuid REFERENCES public.profiles(id),
  performed_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vendors_status ON public.vendors(status);
CREATE INDEX IF NOT EXISTS idx_vendors_preferred ON public.vendors(preferred_vendor);
CREATE INDEX IF NOT EXISTS idx_vendors_rating ON public.vendors(rating) WHERE rating IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_vendor_contacts_vendor ON public.vendor_contacts(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_contacts_primary ON public.vendor_contacts(is_primary) WHERE is_primary = true;
CREATE INDEX IF NOT EXISTS idx_vendor_contracts_vendor ON public.vendor_contracts(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_contracts_status ON public.vendor_contracts(status);
CREATE INDEX IF NOT EXISTS idx_vendor_contracts_end_date ON public.vendor_contracts(end_date) WHERE end_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_vendor_part_mappings_vendor ON public.vendor_part_mappings(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_part_mappings_part ON public.vendor_part_mappings(part_id);
CREATE INDEX IF NOT EXISTS idx_vendor_part_mappings_preferred ON public.vendor_part_mappings(is_preferred_vendor) WHERE is_preferred_vendor = true;
CREATE INDEX IF NOT EXISTS idx_vendor_performance_vendor ON public.vendor_performance_metrics(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_performance_type ON public.vendor_performance_metrics(metric_type);
CREATE INDEX IF NOT EXISTS idx_vendor_performance_period ON public.vendor_performance_metrics(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_vendor_payments_vendor ON public.vendor_payments(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payments_date ON public.vendor_payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_vendor_payments_status ON public.vendor_payments(status);
CREATE INDEX IF NOT EXISTS idx_vendor_audit_vendor ON public.vendor_audit_log(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_audit_date ON public.vendor_audit_log(performed_at);

-- Enable RLS on new tables
ALTER TABLE public.vendor_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_part_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_performance_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_audit_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "All users can view vendor categories"
  ON public.vendor_categories FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage vendor categories"
  ON public.vendor_categories FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = (SELECT auth.uid()) AND profiles.role = 'admin'));

CREATE POLICY "Users can view vendor contacts"
  ON public.vendor_contacts FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage vendor contacts"
  ON public.vendor_contacts FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = (SELECT auth.uid()) AND profiles.role IN ('admin', 'dispatcher')));

CREATE POLICY "Users can view vendor contracts"
  ON public.vendor_contracts FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage vendor contracts"
  ON public.vendor_contracts FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = (SELECT auth.uid()) AND profiles.role IN ('admin', 'dispatcher')));

CREATE POLICY "Users can view vendor part mappings"
  ON public.vendor_part_mappings FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage vendor part mappings"
  ON public.vendor_part_mappings FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = (SELECT auth.uid()) AND profiles.role IN ('admin', 'dispatcher')));

CREATE POLICY "Users can view vendor performance"
  ON public.vendor_performance_metrics FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can record vendor performance"
  ON public.vendor_performance_metrics FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = (SELECT auth.uid()) AND profiles.role IN ('admin', 'dispatcher')));

CREATE POLICY "Admins can view vendor payments"
  ON public.vendor_payments FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = (SELECT auth.uid()) AND profiles.role IN ('admin', 'dispatcher')));

CREATE POLICY "Admins can manage vendor payments"
  ON public.vendor_payments FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = (SELECT auth.uid()) AND profiles.role IN ('admin', 'dispatcher')));

CREATE POLICY "Admins can view audit log"
  ON public.vendor_audit_log FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = (SELECT auth.uid()) AND profiles.role = 'admin'));

CREATE POLICY "System can insert audit entries"
  ON public.vendor_audit_log FOR INSERT TO authenticated WITH CHECK (true);

-- Seed vendor categories
INSERT INTO public.vendor_categories (name, description) VALUES
  ('HVAC Parts', 'Heating, ventilation, and air conditioning parts suppliers'),
  ('Tools & Equipment', 'Tools and equipment suppliers'),
  ('Subcontractor Services', 'Service subcontractors'),
  ('Office Supplies', 'Office and administrative supplies'),
  ('Electrical Components', 'Electrical parts and components'),
  ('Refrigerants', 'Refrigerant suppliers'),
  ('Controls & Thermostats', 'Control systems and thermostat suppliers'),
  ('Ductwork & Sheet Metal', 'Ductwork and sheet metal suppliers')
ON CONFLICT (name) DO NOTHING;
