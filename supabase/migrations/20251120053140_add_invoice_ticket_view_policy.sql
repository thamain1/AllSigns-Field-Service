/*
  # Add RLS policy for viewing tickets referenced in invoices

  1. Changes
    - Add new SELECT policy on tickets table to allow users to view tickets that are referenced in invoices they can view
    - This allows the invoice list to properly join and display ticket information
  
  2. Security
    - Policy ensures users can only see ticket details for invoices they have access to
    - Maintains data isolation while enabling proper invoice display
*/

-- Add policy to allow viewing tickets referenced in invoices
CREATE POLICY "Users can view tickets referenced in their invoices"
  ON tickets
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM invoices 
      WHERE invoices.ticket_id = tickets.id
    )
  );