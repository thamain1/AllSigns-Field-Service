/*
  # Create admin password update function

  1. New Functions
    - `admin_update_user_password` - Allows admins to update any user's password
    
  2. Security
    - Function is SECURITY DEFINER (runs with elevated privileges)
    - Checks that calling user is an admin
    - Updates password in auth.users table directly
*/

-- Create function to update user password (admin only)
CREATE OR REPLACE FUNCTION public.admin_update_user_password(
  target_user_id uuid,
  new_password text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  calling_user_id uuid;
  is_admin_user boolean;
  password_hash text;
BEGIN
  -- Get the calling user's ID
  calling_user_id := auth.uid();
  
  IF calling_user_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Unauthorized: No user session'
    );
  END IF;
  
  -- Check if calling user is admin
  SELECT (role = 'admin') INTO is_admin_user
  FROM public.profiles
  WHERE id = calling_user_id;
  
  IF NOT is_admin_user THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Unauthorized: Only admins can update passwords'
    );
  END IF;
  
  -- Validate password length
  IF length(new_password) < 6 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Password must be at least 6 characters'
    );
  END IF;
  
  -- Hash the password using crypt (same method Supabase uses)
  password_hash := crypt(new_password, gen_salt('bf'));
  
  -- Update the password in auth.users
  UPDATE auth.users
  SET 
    encrypted_password = password_hash,
    updated_at = now()
  WHERE id = target_user_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'message', 'Password updated successfully'
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.admin_update_user_password(uuid, text) TO authenticated;
