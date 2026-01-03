/*
  # Allow Users to Create Their Own Profile

  ## Problem
  Users signing up cannot create their profile record because only admins 
  can insert profiles, creating a chicken-and-egg problem.

  ## Solution
  Add a policy that allows authenticated users to create their own profile
  (where the profile id matches their auth.uid()).

  ## Changes
  1. Add policy allowing users to insert their own profile record
*/

-- Allow users to create their own profile during signup
CREATE POLICY "Users can create own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());
