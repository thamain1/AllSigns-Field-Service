/*
  # Add Mock Technicians

  1. Changes
    - Insert 4 mock technician profiles
      - Scott
      - Jacob
      - Kammi
      - Owen
  
  2. Notes
    - Creates auth users first, then profiles
    - All technicians are set as active
    - Uses temporary email addresses
*/

DO $$
DECLARE
  scott_id uuid := gen_random_uuid();
  jacob_id uuid := gen_random_uuid();
  kammi_id uuid := gen_random_uuid();
  owen_id uuid := gen_random_uuid();
BEGIN
  -- Check if users already exist, if not create them
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'scott@dunawayheating.com') THEN
    scott_id := gen_random_uuid();
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data,
      aud,
      role
    ) VALUES (
      scott_id,
      '00000000-0000-0000-0000-000000000000',
      'scott@dunawayheating.com',
      crypt('password123', gen_salt('bf')),
      now(),
      now(),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{}',
      'authenticated',
      'authenticated'
    );
    
    INSERT INTO profiles (id, email, full_name, role, is_active)
    VALUES (scott_id, 'scott@dunawayheating.com', 'Scott', 'technician', true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'jacob@dunawayheating.com') THEN
    jacob_id := gen_random_uuid();
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data,
      aud,
      role
    ) VALUES (
      jacob_id,
      '00000000-0000-0000-0000-000000000000',
      'jacob@dunawayheating.com',
      crypt('password123', gen_salt('bf')),
      now(),
      now(),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{}',
      'authenticated',
      'authenticated'
    );
    
    INSERT INTO profiles (id, email, full_name, role, is_active)
    VALUES (jacob_id, 'jacob@dunawayheating.com', 'Jacob', 'technician', true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'kammi@dunawayheating.com') THEN
    kammi_id := gen_random_uuid();
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data,
      aud,
      role
    ) VALUES (
      kammi_id,
      '00000000-0000-0000-0000-000000000000',
      'kammi@dunawayheating.com',
      crypt('password123', gen_salt('bf')),
      now(),
      now(),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{}',
      'authenticated',
      'authenticated'
    );
    
    INSERT INTO profiles (id, email, full_name, role, is_active)
    VALUES (kammi_id, 'kammi@dunawayheating.com', 'Kammi', 'technician', true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'owen@dunawayheating.com') THEN
    owen_id := gen_random_uuid();
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      raw_app_meta_data,
      raw_user_meta_data,
      aud,
      role
    ) VALUES (
      owen_id,
      '00000000-0000-0000-0000-000000000000',
      'owen@dunawayheating.com',
      crypt('password123', gen_salt('bf')),
      now(),
      now(),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{}',
      'authenticated',
      'authenticated'
    );
    
    INSERT INTO profiles (id, email, full_name, role, is_active)
    VALUES (owen_id, 'owen@dunawayheating.com', 'Owen', 'technician', true);
  END IF;
END $$;
