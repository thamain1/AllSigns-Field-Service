/*
  # Fix Customer Locations RLS for Technician Role
  
  1. Changes
    - Drop overly permissive INSERT/UPDATE/DELETE policies on customer_locations
    - Create new policies that restrict modifications to admin and dispatcher only
    - Keep SELECT policy allowing all authenticated users (including technicians)
  
  2. Security
    - Technicians can view customer locations (needed for equipment info)
    - Only admin and dispatcher can modify customer locations
    - Prevents unauthorized data modification
*/

-- Drop existing overly permissive policies
DROP POLICY IF EXISTS "Authenticated users can insert customer locations" ON customer_locations;
DROP POLICY IF EXISTS "Authenticated users can update customer locations" ON customer_locations;
DROP POLICY IF EXISTS "Authenticated users can delete customer locations" ON customer_locations;

-- Create restrictive policies for modifications (admin and dispatcher only)
CREATE POLICY "Admins and dispatchers can insert customer locations"
  ON customer_locations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

CREATE POLICY "Admins and dispatchers can update customer locations"
  ON customer_locations
  FOR UPDATE
  TO authenticated
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

CREATE POLICY "Admins and dispatchers can delete customer locations"
  ON customer_locations
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );
