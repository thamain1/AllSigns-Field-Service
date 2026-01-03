/*
  # Fix Ticket Photos Storage Bucket

  1. Changes
    - Make ticket-photos bucket public for easier access
    - This allows the getPublicUrl() method to work correctly
  
  2. Security
    - RLS policies still control who can upload/delete
    - Public only means the URLs are accessible without authentication
    - This is standard for user-uploaded images that need to be viewed
*/

-- Make the ticket-photos bucket public
UPDATE storage.buckets
SET public = true
WHERE name = 'ticket-photos';
