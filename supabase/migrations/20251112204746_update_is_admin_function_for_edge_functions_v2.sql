/*
  # Update is_admin function to work with Edge Functions

  1. Changes
    - Drop the policy that depends on is_admin
    - Update is_admin function to accept optional user_id parameter
    - Recreate the policy
    
  2. Security
    - Function is still SECURITY DEFINER so it bypasses RLS
    - Only checks if a user is admin, doesn't expose other data
*/

-- Drop the policy that depends on the function
DROP POLICY IF EXISTS "Admins can update any profile" ON profiles;

-- Drop and recreate the function with optional parameter
DROP FUNCTION IF EXISTS public.is_admin();

CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = COALESCE(user_id, auth.uid())
    AND role = 'admin'
  );
$$;

-- Recreate the policy using the updated function
CREATE POLICY "Admins can update any profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
