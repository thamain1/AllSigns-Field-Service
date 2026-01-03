/*
  # Seed Contract Plan Templates

  1. Seed Data
    - Create Silver plan (basic maintenance)
    - Create Gold plan (enhanced coverage)
    - Create Platinum plan (premium service)

  2. Important Notes
    - Plans have placeholder values that can be tuned later
    - All plans are active by default
    - Plans serve as templates for creating customer contracts
*/

-- Insert Silver Plan (Basic Maintenance)
INSERT INTO contract_plans (
  name,
  description,
  is_active,
  labor_rate_type,
  labor_discount_percent,
  parts_discount_percent,
  trip_charge_discount_percent,
  waive_trip_charge,
  includes_emergency_service,
  includes_after_hours_rate_reduction,
  included_visits_per_year,
  priority_level,
  response_time_sla_hours,
  billing_frequency,
  default_base_fee
) VALUES (
  'Silver',
  'Basic maintenance agreement with one annual preventive maintenance visit and 10% discounts on parts and labor.',
  true,
  'discount_percentage',
  10.00,
  10.00,
  50.00,
  false,
  false,
  false,
  1,
  'normal',
  48.00,
  'annual',
  299.00
) ON CONFLICT DO NOTHING;

-- Insert Gold Plan (Enhanced Coverage)
INSERT INTO contract_plans (
  name,
  description,
  is_active,
  labor_rate_type,
  labor_discount_percent,
  parts_discount_percent,
  trip_charge_discount_percent,
  waive_trip_charge,
  includes_emergency_service,
  includes_after_hours_rate_reduction,
  included_visits_per_year,
  priority_level,
  response_time_sla_hours,
  billing_frequency,
  default_base_fee
) VALUES (
  'Gold',
  'Enhanced maintenance agreement with two annual preventive maintenance visits, priority service, 15% discounts, and waived trip charges.',
  true,
  'discount_percentage',
  15.00,
  15.00,
  100.00,
  true,
  false,
  true,
  2,
  'priority',
  24.00,
  'annual',
  599.00
) ON CONFLICT DO NOTHING;

-- Insert Platinum Plan (Premium Service)
INSERT INTO contract_plans (
  name,
  description,
  is_active,
  labor_rate_type,
  labor_discount_percent,
  parts_discount_percent,
  trip_charge_discount_percent,
  waive_trip_charge,
  includes_emergency_service,
  includes_after_hours_rate_reduction,
  included_visits_per_year,
  priority_level,
  response_time_sla_hours,
  billing_frequency,
  default_base_fee
) VALUES (
  'Platinum',
  'Premium maintenance agreement with four annual preventive maintenance visits, VIP priority, 20% discounts, emergency service coverage, and waived trip charges.',
  true,
  'discount_percentage',
  20.00,
  20.00,
  100.00,
  true,
  true,
  true,
  4,
  'vip',
  12.00,
  'annual',
  999.00
) ON CONFLICT DO NOTHING;
