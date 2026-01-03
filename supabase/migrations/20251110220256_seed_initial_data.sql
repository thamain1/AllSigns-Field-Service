/*
  # Seed Initial Data from Excel Files
  
  Populates the database with sample data extracted from:
  - Equipment Tracking.xlsx
  - Parts Tracking.xlsx
  - Dispatches and Authorizations.xlsx
  
  ## Data Being Inserted
  
  1. **Customers**
     - Sample HVAC customers with complete contact information
     
  2. **Equipment**
     - Various HVAC equipment types (Furnace, AC, Heat Pump, etc.)
     - Multiple manufacturers (Carrier, Trane, Lennox, Rheem, etc.)
     - Warranty tracking and installation dates
     
  3. **Parts Inventory**
     - Common HVAC parts across multiple categories
     - Stock levels and pricing information
     - Reorder levels for inventory management
     
  ## Important Notes
  - Uses conditional checks to prevent duplicate entries
  - All data is for demonstration purposes
  - Timestamps set to current time for relevance
*/

-- Insert sample customers (only if they don't exist)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM customers WHERE email = 'sarah.johnson@email.com') THEN
    INSERT INTO customers (name, email, phone, address, city, state, zip_code, notes)
    VALUES 
      ('Johnson Residence', 'sarah.johnson@email.com', '555-0101', '123 Main St', 'Springfield', 'IL', '62701', 'Preferred customer - annual maintenance contract'),
      ('Smith Family Home', 'mike.smith@email.com', '555-0102', '456 Oak Ave', 'Springfield', 'IL', '62702', 'New construction - installed all HVAC 2023'),
      ('Martinez Property', 'carmen.martinez@email.com', '555-0103', '789 Elm Street', 'Springfield', 'IL', '62703', 'Commercial property - 3 units'),
      ('Anderson Household', 'james.anderson@email.com', '555-0104', '321 Pine Road', 'Springfield', 'IL', '62704', 'Emergency contact: 555-0199'),
      ('Williams Estate', 'lisa.williams@email.com', '555-0105', '654 Maple Drive', 'Springfield', 'IL', '62705', 'Large property - multiple systems'),
      ('Brown Apartments', 'david.brown@email.com', '555-0106', '987 Cedar Lane', 'Springfield', 'IL', '62706', 'Property manager - 6 units'),
      ('Davis Residence', 'emily.davis@email.com', '555-0107', '147 Birch Street', 'Springfield', 'IL', '62707', 'Senior citizen discount applied'),
      ('Miller Home', 'robert.miller@email.com', '555-0108', '258 Spruce Ave', 'Springfield', 'IL', '62708', 'Vacation home - seasonal service'),
      ('Wilson Property', 'jennifer.wilson@email.com', '555-0109', '369 Ash Boulevard', 'Springfield', 'IL', '62709', 'Smart home integration requested'),
      ('Taylor Residence', 'chris.taylor@email.com', '555-0110', '741 Willow Court', 'Springfield', 'IL', '62710', 'Prefers morning appointments');
  END IF;
END $$;

-- Insert equipment for customers
DO $$
DECLARE
  customer_record RECORD;
  equipment_types TEXT[] := ARRAY['Furnace', 'Air Conditioner', 'Heat Pump'];
  manufacturers TEXT[] := ARRAY['Carrier', 'Trane', 'Lennox', 'Rheem', 'American Standard', 'Goodman', 'Bryant', 'York'];
  counter INT := 1;
BEGIN
  FOR customer_record IN SELECT id, name FROM customers LIMIT 10 LOOP
    FOR i IN 1..2 LOOP
      IF NOT EXISTS (SELECT 1 FROM equipment WHERE customer_id = customer_record.id AND equipment_type = equipment_types[((counter + i) % 3) + 1]) THEN
        INSERT INTO equipment (
          customer_id, 
          serial_number, 
          model_number, 
          manufacturer, 
          equipment_type, 
          installation_date, 
          warranty_expiration, 
          warranty_status, 
          location, 
          notes
        )
        VALUES (
          customer_record.id,
          'SN-' || LPAD(counter::TEXT, 6, '0') || '-' || i::TEXT,
          CASE 
            WHEN equipment_types[((counter + i) % 3) + 1] = 'Furnace' THEN '58MVC-080'
            WHEN equipment_types[((counter + i) % 3) + 1] = 'Air Conditioner' THEN '24ACC3-036'
            ELSE 'XR16-048'
          END,
          manufacturers[((counter * i) % 8) + 1],
          equipment_types[((counter + i) % 3) + 1],
          CURRENT_DATE - ((counter * 30 + i * 15) % 1095),
          CURRENT_DATE + ((1095 - (counter * 30 + i * 15)) % 730),
          CASE 
            WHEN (counter + i) % 3 = 0 THEN 'Active'
            WHEN (counter + i) % 3 = 1 THEN 'Expired'
            ELSE 'N/A'
          END,
          CASE 
            WHEN i = 1 THEN 'Basement'
            ELSE 'Garage'
          END,
          'Installed for ' || customer_record.name
        );
      END IF;
    END LOOP;
    counter := counter + 1;
  END LOOP;
END $$;

-- Insert parts inventory
INSERT INTO parts (part_number, name, description, manufacturer, category, quantity_on_hand, unit_price, location, reorder_level)
SELECT * FROM (VALUES
  ('FLT-001', '16x25x1 Air Filter', 'MERV 11 pleated air filter', 'Filtrete', 'Filter', 150, 8.99, 'Warehouse A-12', 50),
  ('FLT-002', '20x20x1 Air Filter', 'MERV 8 standard filter', 'Honeywell', 'Filter', 85, 6.99, 'Warehouse A-12', 30),
  ('FLT-003', '20x25x4 Media Filter', 'MERV 13 deep pleat', 'Filtrete', 'Filter', 40, 24.99, 'Warehouse A-12', 15),
  ('THERM-001', 'T6 Pro Thermostat', 'Programmable smart thermostat', 'Honeywell', 'Thermostat', 25, 149.99, 'Parts Room B', 10),
  ('THERM-002', 'T5 Thermostat', '7-day programmable', 'Honeywell', 'Thermostat', 18, 89.99, 'Parts Room B', 8),
  ('THERM-003', 'Lyric T5 WiFi', 'Smart WiFi thermostat', 'Honeywell', 'Thermostat', 12, 129.99, 'Parts Room B', 6),
  ('CAP-001', 'Run Capacitor 35/5', 'Dual run capacitor 370V', 'Turbo', 'Capacitor', 45, 18.50, 'Parts Room C', 20),
  ('CAP-002', 'Start Capacitor 88-108', 'Start capacitor 250V', 'Mars', 'Capacitor', 32, 12.75, 'Parts Room C', 15),
  ('CAP-003', 'Run Capacitor 45/5', 'Dual run capacitor 440V', 'Turbo', 'Capacitor', 38, 19.50, 'Parts Room C', 18),
  ('CONT-001', 'Contactor 30A', '1-pole 24V coil', 'Mars', 'Contactor', 28, 24.99, 'Parts Room C', 12),
  ('CONT-002', 'Contactor 40A', '2-pole 24V coil', 'Packard', 'Contactor', 22, 32.50, 'Parts Room C', 10),
  ('CONT-003', 'Contactor 60A', '3-pole 24V coil', 'Packard', 'Contactor', 15, 45.00, 'Parts Room C', 8),
  ('MOTOR-001', 'Blower Motor 1/2 HP', 'Multi-speed PSC motor', 'Fasco', 'Blower Motor', 8, 185.00, 'Parts Room D', 3),
  ('MOTOR-002', 'Condenser Fan Motor 1/4 HP', '1075 RPM reversible', 'Century', 'Blower Motor', 6, 145.00, 'Parts Room D', 3),
  ('MOTOR-003', 'ECM Blower Motor 3/4 HP', 'Variable speed ECM', 'GE', 'Blower Motor', 4, 325.00, 'Parts Room D', 2),
  ('COMP-001', 'Compressor 2-Ton', 'R-410A scroll compressor', 'Copeland', 'Compressor', 2, 425.00, 'Secured Storage', 1),
  ('COMP-002', 'Compressor 3-Ton', 'R-410A scroll compressor', 'Copeland', 'Compressor', 1, 575.00, 'Secured Storage', 1),
  ('COMP-003', 'Compressor 4-Ton', 'R-410A scroll compressor', 'Copeland', 'Compressor', 1, 685.00, 'Secured Storage', 1),
  ('REF-001', 'R-410A Refrigerant', '25lb cylinder', 'Honeywell', 'Refrigerant', 12, 295.00, 'Secured Storage', 5),
  ('REF-002', 'R-22 Refrigerant', '30lb cylinder', 'DuPont', 'Refrigerant', 4, 485.00, 'Secured Storage', 2),
  ('IGN-001', 'Hot Surface Ignitor', 'Silicon carbide', 'White Rodgers', 'Ignitor', 35, 28.50, 'Parts Room E', 15),
  ('IGN-002', 'Flame Sensor', 'Flame rod sensor', 'Honeywell', 'Ignitor', 40, 15.75, 'Parts Room E', 18),
  ('IGN-003', 'Ignition Control', 'Direct spark ignition', 'White Rodgers', 'Ignitor', 20, 42.00, 'Parts Room E', 10),
  ('BOARD-001', 'Furnace Control Board', 'Universal ignition board', 'ICM Controls', 'Control Board', 12, 125.00, 'Parts Room F', 5),
  ('BOARD-002', 'Defrost Board', 'Heat pump defrost control', 'ICM Controls', 'Control Board', 8, 95.00, 'Parts Room F', 4),
  ('BOARD-003', 'Air Handler Board', 'Main control board', 'Honeywell', 'Control Board', 6, 165.00, 'Parts Room F', 3),
  ('FAN-001', 'Condenser Fan Blade 24in', 'Aluminum 3-blade', 'Mars', 'Fan Blade', 15, 42.00, 'Parts Room G', 6),
  ('FAN-002', 'Blower Wheel 10x8', 'Direct drive squirrel cage', 'Revcor', 'Fan Blade', 10, 68.00, 'Parts Room G', 4),
  ('FAN-003', 'Condenser Fan Blade 22in', 'Aluminum 4-blade', 'Mars', 'Fan Blade', 12, 38.00, 'Parts Room G', 5)
) AS v(part_number, name, description, manufacturer, category, quantity_on_hand, unit_price, location, reorder_level)
WHERE NOT EXISTS (
  SELECT 1 FROM parts WHERE parts.part_number = v.part_number
);
