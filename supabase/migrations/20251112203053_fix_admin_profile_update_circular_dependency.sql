/*
  # Fix Admin Profile Update Policy

  1. Problem
    - The admin update policy causes infinite recursion by querying profiles table within RLS policy
    
  2. Solution
    - Create a security definer function to check if user is admin
    - This bypasses RLS when checking the user's own role
    - Update the policy to use this function
    
  3. Security
    - Function only checks if the calling user is an admin
    - Does not expose any other user data
*/

-- Drop existing admin update policy
DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;

-- Create a security definer function to check if current user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  );
$$;

-- Recreate the admin update policy using the function
CREATE POLICY "Admins can update any profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
