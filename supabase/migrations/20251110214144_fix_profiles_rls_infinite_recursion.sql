/*
  # Fix Profiles RLS Infinite Recursion

  ## Problem
  The "Admins can manage all profiles" policy was causing infinite recursion because it queries 
  the profiles table within its own policy check.

  ## Solution
  Replace the recursive policy with direct checks using auth.uid() and storing the role check
  in a simpler way. We'll drop the problematic policy and recreate it without the self-referencing
  subquery.

  ## Changes
  1. Drop the existing "Admins can manage all profiles" policy
  2. Create separate policies for INSERT, UPDATE, DELETE that use a helper function
  3. Create a helper function to check user role without recursion
*/

-- Drop the problematic policy
DROP POLICY IF EXISTS "Admins can manage all profiles" ON profiles;

-- Create a helper function to get current user role without recursion
CREATE OR REPLACE FUNCTION get_current_user_role()
RETURNS user_role AS $$
BEGIN
  RETURN (
    SELECT role FROM profiles WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Create new policies for admins without recursion
CREATE POLICY "Admins can insert profiles"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (get_current_user_role() = 'admin');

CREATE POLICY "Admins can delete profiles"
  ON profiles FOR DELETE
  TO authenticated
  USING (get_current_user_role() = 'admin');

CREATE POLICY "Admins can update any profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (get_current_user_role() = 'admin');
