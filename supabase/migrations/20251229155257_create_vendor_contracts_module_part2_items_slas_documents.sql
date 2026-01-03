/*
  # Create Vendor Contracts Module - Part 2: Contract Items, SLAs, and Documents

  1. New Tables
    - `vendor_contract_items`
      - Item-level or category-level pricing under a contract
      - Supports fixed prices, discount percentages, quantity breaks
      - Lead time and availability overrides
    
    - `vendor_contract_slas`
      - Service level agreements and performance targets
      - Integrates with vendor performance scores
    
    - `vendor_contract_documents`
      - Contract attachments and reference documents
      - Tracks expiration dates for time-sensitive docs

  2. Additive FK to Existing Table
    - Add nullable `vendor_contract_id` to `purchase_orders`
    - Allows POs to reference the governing contract

  3. Security
    - RLS enabled on all new tables
    - Same permission model as main contracts table

  4. Important Notes
    - All changes are additive and non-destructive
    - Existing POs continue to work (vendor_contract_id defaults to NULL)
*/

-- =====================================================
-- CONTRACT ITEMS (PRICING)
-- =====================================================

CREATE TABLE IF NOT EXISTS vendor_contract_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_contract_id uuid NOT NULL REFERENCES vendor_contracts(id) ON DELETE CASCADE,
  
  -- What does this item cover?
  part_id uuid REFERENCES parts(id) ON DELETE CASCADE,
  part_category text,
  item_description_override text,
  
  -- Pricing terms
  price_type contract_price_type NOT NULL DEFAULT 'fixed',
  contract_price numeric(10, 2),
  discount_percent numeric(5, 2),
  pricing_basis pricing_basis DEFAULT 'list_price',
  
  -- Quantity breaks
  start_quantity_break numeric(10, 2) DEFAULT 0,
  end_quantity_break numeric(10, 2),
  
  -- Lead time / availability overrides
  lead_time_days_override integer,
  is_core_item boolean DEFAULT false,
  
  -- Effective dates (for staged pricing)
  effective_start_date date,
  effective_end_date date,
  
  -- Notes
  notes text,
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- Constraints
  CONSTRAINT at_least_one_item_identifier CHECK (
    part_id IS NOT NULL OR part_category IS NOT NULL
  ),
  CONSTRAINT valid_pricing CHECK (
    (price_type = 'fixed' AND contract_price IS NOT NULL) OR
    (price_type = 'discount_percent' AND discount_percent IS NOT NULL) OR
    price_type = 'formula'
  ),
  CONSTRAINT valid_quantity_break CHECK (
    end_quantity_break IS NULL OR end_quantity_break > start_quantity_break
  ),
  CONSTRAINT valid_effective_dates CHECK (
    effective_end_date IS NULL OR effective_end_date >= effective_start_date
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_contract_items_contract_id ON vendor_contract_items(vendor_contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_items_part_id ON vendor_contract_items(part_id);
CREATE INDEX IF NOT EXISTS idx_contract_items_category ON vendor_contract_items(part_category);
CREATE INDEX IF NOT EXISTS idx_contract_items_effective_dates ON vendor_contract_items(effective_start_date, effective_end_date);

-- =====================================================
-- CONTRACT SLAS (SERVICE LEVELS)
-- =====================================================

CREATE TABLE IF NOT EXISTS vendor_contract_slas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_contract_id uuid NOT NULL REFERENCES vendor_contracts(id) ON DELETE CASCADE,
  
  -- SLA metric definition
  metric contract_sla_metric NOT NULL,
  metric_description text,
  target_value numeric(10, 2) NOT NULL,
  target_unit text NOT NULL,
  breach_threshold numeric(10, 2),
  
  -- Notes
  notes text,
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_contract_slas_contract_id ON vendor_contract_slas(vendor_contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_slas_metric ON vendor_contract_slas(metric);

-- =====================================================
-- CONTRACT DOCUMENTS (ATTACHMENTS)
-- =====================================================

CREATE TABLE IF NOT EXISTS vendor_contract_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_contract_id uuid NOT NULL REFERENCES vendor_contracts(id) ON DELETE CASCADE,
  
  -- Document metadata
  document_type contract_document_type NOT NULL,
  file_name text NOT NULL,
  storage_key text,
  file_size_bytes bigint,
  mime_type text,
  
  -- Expiration tracking (e.g., insurance expires)
  expires_at timestamptz,
  
  -- Audit
  uploaded_at timestamptz DEFAULT now(),
  uploaded_by_user_id uuid REFERENCES profiles(id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_contract_documents_contract_id ON vendor_contract_documents(vendor_contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_documents_type ON vendor_contract_documents(document_type);
CREATE INDEX IF NOT EXISTS idx_contract_documents_expiration ON vendor_contract_documents(expires_at) 
  WHERE expires_at IS NOT NULL;

-- =====================================================
-- ADDITIVE FK TO EXISTING TABLE
-- =====================================================

-- Add nullable vendor_contract_id to purchase_orders
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'purchase_orders' 
      AND column_name = 'vendor_contract_id'
  ) THEN
    ALTER TABLE purchase_orders 
    ADD COLUMN vendor_contract_id uuid REFERENCES vendor_contracts(id) ON DELETE SET NULL;
    
    CREATE INDEX IF NOT EXISTS idx_purchase_orders_vendor_contract_id 
      ON purchase_orders(vendor_contract_id);
  END IF;
END $$;

-- =====================================================
-- RLS POLICIES FOR NEW TABLES
-- =====================================================

-- Contract Items
ALTER TABLE vendor_contract_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view vendor contract items"
  ON vendor_contract_items FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admins and dispatchers can manage vendor contract items"
  ON vendor_contract_items FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'dispatcher')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'dispatcher')
    )
  );

-- Contract SLAs
ALTER TABLE vendor_contract_slas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view vendor contract SLAs"
  ON vendor_contract_slas FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admins and dispatchers can manage vendor contract SLAs"
  ON vendor_contract_slas FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'dispatcher')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'dispatcher')
    )
  );

-- Contract Documents
ALTER TABLE vendor_contract_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view vendor contract documents"
  ON vendor_contract_documents FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admins and dispatchers can manage vendor contract documents"
  ON vendor_contract_documents FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'dispatcher')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin', 'dispatcher')
    )
  );

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Auto-update updated_at for contract items
CREATE OR REPLACE FUNCTION update_vendor_contract_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER vendor_contract_items_updated_at
  BEFORE UPDATE ON vendor_contract_items
  FOR EACH ROW
  EXECUTE FUNCTION update_vendor_contract_items_updated_at();

-- Auto-update updated_at for contract SLAs
CREATE OR REPLACE FUNCTION update_vendor_contract_slas_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER vendor_contract_slas_updated_at
  BEFORE UPDATE ON vendor_contract_slas
  FOR EACH ROW
  EXECUTE FUNCTION update_vendor_contract_slas_updated_at();
