/*
  # Allow Admins to Update Any Profile

  1. Changes
    - Add policy for admins to update any user's profile information
    - Admins can modify full_name, role, phone, labor_cost_per_hour for any user
  
  2. Security
    - Only users with role='admin' can update other users' profiles
    - Regular users can still only update their own profile
*/

-- Drop the existing restrictive update policy
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

-- Create new policies: one for users updating their own, one for admins updating any
CREATE POLICY "Users can update own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Admins can update any profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );
