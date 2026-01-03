/*
  # Add Public Access to Ticket Photos

  This migration adds policies to allow public (anonymous) access to view ticket photos
  since the bucket is marked as public. This ensures photos can be viewed even without
  authentication, which is necessary for the public URLs to work properly.

  1. Changes
    - Add SELECT policy for anon role to view ticket photos
    - This complements the existing authenticated policies

  2. Security
    - Only SELECT access is granted to anon users
    - Upload, update, and delete remain restricted to authenticated users
*/

-- Drop the policy if it exists
DROP POLICY IF EXISTS "Public users can view ticket photos" ON storage.objects;

-- Allow public (anon) users to view ticket photos
CREATE POLICY "Public users can view ticket photos"
  ON storage.objects
  FOR SELECT
  TO anon
  USING (bucket_id = 'ticket-photos');
