/*
  # Create Vendor Contracts Helper Functions and Views

  1. Helper Functions
    - `get_active_vendor_contracts` - Get active contracts for a vendor on a given date
    - `get_contract_price_for_part` - Calculate contract price for a part/quantity
    - `get_contracts_expiring_soon` - Find contracts expiring within N days

  2. Views
    - `v_vendor_contracts_summary` - Contract summary with vendor details
    - `v_contract_pricing_lookup` - Fast lookup for contract pricing

  3. Important Notes
    - All functions are read-only helpers for UI and PO creation
    - No destructive changes to existing data
    - Works with existing vendor_contracts table structure
*/

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Get active contracts for a vendor on a specific date
CREATE OR REPLACE FUNCTION get_active_vendor_contracts(
  p_vendor_id uuid,
  p_as_of_date date DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  contract_id uuid,
  contract_number text,
  contract_type text,
  start_date date,
  end_date date,
  payment_terms text,
  freight_terms text,
  standard_lead_time_days integer,
  is_preferred_vendor boolean
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    vc.id,
    vc.contract_number,
    vc.contract_type,
    vc.start_date,
    vc.end_date,
    vc.payment_terms,
    vc.freight_terms,
    vc.standard_lead_time_days,
    COALESCE(vc.is_preferred_vendor, false)
  FROM vendor_contracts vc
  WHERE vc.vendor_id = p_vendor_id
    AND vc.status = 'active'
    AND vc.start_date <= p_as_of_date
    AND (vc.end_date IS NULL OR vc.end_date >= p_as_of_date)
  ORDER BY COALESCE(vc.is_preferred_vendor, false) DESC, vc.start_date DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get contract price for a specific part and quantity
CREATE OR REPLACE FUNCTION get_contract_price_for_part(
  p_contract_id uuid,
  p_part_id uuid,
  p_quantity numeric DEFAULT 1,
  p_as_of_date date DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  item_id uuid,
  price_type contract_price_type,
  final_price numeric,
  discount_percent numeric,
  lead_time_days integer,
  notes text
) AS $$
DECLARE
  v_part_category text;
  v_list_price numeric;
BEGIN
  -- Get part details
  SELECT category, unit_price INTO v_part_category, v_list_price
  FROM parts WHERE id = p_part_id;

  RETURN QUERY
  SELECT 
    vci.id,
    vci.price_type,
    CASE 
      WHEN vci.price_type = 'fixed' THEN vci.contract_price
      WHEN vci.price_type = 'discount_percent' THEN 
        COALESCE(v_list_price, 0) * (1 - COALESCE(vci.discount_percent, 0) / 100)
      ELSE v_list_price
    END as final_price,
    vci.discount_percent,
    COALESCE(vci.lead_time_days_override, 
      (SELECT standard_lead_time_days FROM vendor_contracts WHERE id = p_contract_id)),
    vci.notes
  FROM vendor_contract_items vci
  WHERE vci.vendor_contract_id = p_contract_id
    AND (
      vci.part_id = p_part_id 
      OR (vci.part_id IS NULL AND vci.part_category = v_part_category)
    )
    AND (vci.effective_start_date IS NULL OR vci.effective_start_date <= p_as_of_date)
    AND (vci.effective_end_date IS NULL OR vci.effective_end_date >= p_as_of_date)
    AND (vci.start_quantity_break <= p_quantity)
    AND (vci.end_quantity_break IS NULL OR vci.end_quantity_break >= p_quantity)
  ORDER BY 
    vci.part_id NULLS LAST,
    vci.start_quantity_break DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- Find contracts expiring within N days
CREATE OR REPLACE FUNCTION get_contracts_expiring_soon(
  p_days_ahead integer DEFAULT 30
)
RETURNS TABLE (
  contract_id uuid,
  vendor_id uuid,
  vendor_name text,
  contract_number text,
  end_date date,
  days_until_expiration integer,
  auto_renew boolean
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    vc.id,
    vc.vendor_id,
    v.name,
    vc.contract_number,
    vc.end_date,
    (vc.end_date - CURRENT_DATE) as days_until_expiration,
    COALESCE(vc.auto_renew, false)
  FROM vendor_contracts vc
  JOIN vendors v ON v.id = vc.vendor_id
  WHERE vc.status = 'active'
    AND vc.end_date IS NOT NULL
    AND vc.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + p_days_ahead
  ORDER BY vc.end_date ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- =====================================================
-- VIEWS
-- =====================================================

-- Vendor contracts summary with vendor details
CREATE OR REPLACE VIEW v_vendor_contracts_summary AS
SELECT 
  vc.id,
  vc.vendor_id,
  v.name as vendor_name,
  v.vendor_code,
  vc.contract_number,
  vc.contract_type,
  vc.status,
  vc.start_date,
  vc.end_date,
  vc.payment_terms,
  vc.freight_terms,
  vc.standard_lead_time_days,
  vc.minimum_order_value,
  COALESCE(vc.is_preferred_vendor, false) as is_preferred_vendor,
  COALESCE(vc.auto_renew, false) as auto_renew,
  vc.renewal_term_months,
  vc.notes,
  vc.created_at,
  vc.updated_at,
  vc.contract_value,
  vc.document_name,
  vc.document_url,
  -- Computed fields
  CASE 
    WHEN vc.end_date IS NULL THEN NULL
    ELSE vc.end_date - CURRENT_DATE
  END as days_until_expiration,
  (SELECT COUNT(*) FROM vendor_contract_items vci WHERE vci.vendor_contract_id = vc.id) as item_count,
  (SELECT COUNT(*) FROM vendor_contract_slas vcs WHERE vcs.vendor_contract_id = vc.id) as sla_count,
  (SELECT COUNT(*) FROM vendor_contract_documents vcd WHERE vcd.vendor_contract_id = vc.id) as document_count
FROM vendor_contracts vc
JOIN vendors v ON v.id = vc.vendor_id;

-- Contract pricing lookup view
CREATE OR REPLACE VIEW v_contract_pricing_lookup AS
SELECT 
  vci.id as item_id,
  vci.vendor_contract_id,
  vc.vendor_id,
  v.name as vendor_name,
  vc.contract_number,
  vc.status as contract_status,
  vci.part_id,
  p.part_number,
  p.name as part_name,
  p.category as part_category,
  vci.part_category as contract_category,
  vci.price_type,
  vci.contract_price,
  vci.discount_percent,
  vci.pricing_basis,
  vci.start_quantity_break,
  vci.end_quantity_break,
  vci.lead_time_days_override,
  vci.is_core_item,
  vci.effective_start_date,
  vci.effective_end_date,
  vc.start_date as contract_start_date,
  vc.end_date as contract_end_date
FROM vendor_contract_items vci
JOIN vendor_contracts vc ON vc.id = vci.vendor_contract_id
JOIN vendors v ON v.id = vc.vendor_id
LEFT JOIN parts p ON p.id = vci.part_id
WHERE vc.status = 'active';

-- =====================================================
-- GRANT PERMISSIONS ON VIEWS
-- =====================================================

GRANT SELECT ON v_vendor_contracts_summary TO authenticated;
GRANT SELECT ON v_contract_pricing_lookup TO authenticated;
