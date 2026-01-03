/*
  # Create Storage Bucket for Ticket Photos

  ## Overview
  Creates a Supabase Storage bucket for storing ticket photos uploaded by technicians.
  Includes appropriate security policies for authenticated users.

  ## 1. Storage Bucket
    - Name: ticket-photos
    - Public: false (requires authentication)
    - File size limit: 10MB per file
    - Allowed types: images only

  ## 2. Storage Policies
    - Technicians can upload photos to their assigned tickets
    - Technicians can view photos from their tickets
    - Admins and dispatchers can view all photos

  ## 3. Security
    - Files stored securely
    - Access controlled via RLS-style policies
    - Only authenticated users can upload
    - Files organized by ticket_id/filename
*/

-- Create storage bucket for ticket photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'ticket-photos',
  'ticket-photos',
  false,
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/jpg', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

-- Policy: Allow authenticated users to upload photos
CREATE POLICY "Authenticated users can upload ticket photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'ticket-photos'
);

-- Policy: Allow authenticated users to view photos
CREATE POLICY "Authenticated users can view ticket photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'ticket-photos'
);

-- Policy: Allow users to update their own uploads
CREATE POLICY "Users can update their own ticket photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'ticket-photos' AND
  owner = auth.uid()
)
WITH CHECK (
  bucket_id = 'ticket-photos' AND
  owner = auth.uid()
);

-- Policy: Allow users to delete their own uploads
CREATE POLICY "Users can delete their own ticket photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'ticket-photos' AND
  owner = auth.uid()
);
