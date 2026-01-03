/*
  # Optimize RLS Policies - Part 1 (Core Tables)

  This migration optimizes RLS policies by wrapping auth function calls in SELECT statements
  to prevent re-evaluation for each row. This significantly improves query performance at scale.

  ## Tables Optimized (Part 1)
  - profiles
  - customers
  - parts
  - activity_log
  - equipment
  - tickets
  - ticket_notes
  - ticket_photos
  - parts_usage
  - technician_locations
*/

-- Drop and recreate optimized policies for PROFILES
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "Users can create own profile" ON public.profiles;
CREATE POLICY "Users can create own profile"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = id);

-- Drop and recreate optimized policies for CUSTOMERS
DROP POLICY IF EXISTS "Admins and dispatchers can manage customers" ON public.customers;
CREATE POLICY "Admins and dispatchers can manage customers"
  ON public.customers
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

-- Drop and recreate optimized policies for PARTS
DROP POLICY IF EXISTS "Admins and dispatchers can manage parts" ON public.parts;
CREATE POLICY "Admins and dispatchers can manage parts"
  ON public.parts
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

-- Drop and recreate optimized policies for ACTIVITY_LOG
DROP POLICY IF EXISTS "Admins can view all activity logs" ON public.activity_log;
CREATE POLICY "Admins can view all activity logs"
  ON public.activity_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Users can view own activity logs" ON public.activity_log;
CREATE POLICY "Users can view own activity logs"
  ON public.activity_log
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "All authenticated users can insert activity logs" ON public.activity_log;
CREATE POLICY "All authenticated users can insert activity logs"
  ON public.activity_log
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

-- Drop and recreate optimized policies for EQUIPMENT
DROP POLICY IF EXISTS "Admins and dispatchers can manage equipment" ON public.equipment;
CREATE POLICY "Admins and dispatchers can manage equipment"
  ON public.equipment
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

-- Drop and recreate optimized policies for TICKETS
DROP POLICY IF EXISTS "Users can view tickets they're involved with" ON public.tickets;
CREATE POLICY "Users can view tickets they're involved with"
  ON public.tickets
  FOR SELECT
  TO authenticated
  USING (
    assigned_to = (SELECT auth.uid()) OR
    created_by = (SELECT auth.uid()) OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Admins and dispatchers can create tickets" ON public.tickets;
CREATE POLICY "Admins and dispatchers can create tickets"
  ON public.tickets
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Admins and dispatchers can update any ticket" ON public.tickets;
CREATE POLICY "Admins and dispatchers can update any ticket"
  ON public.tickets
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Technicians can update assigned tickets" ON public.tickets;
CREATE POLICY "Technicians can update assigned tickets"
  ON public.tickets
  FOR UPDATE
  TO authenticated
  USING (assigned_to = (SELECT auth.uid()))
  WITH CHECK (assigned_to = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admins can delete tickets" ON public.tickets;
CREATE POLICY "Admins can delete tickets"
  ON public.tickets
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role = 'admin'
    )
  );

-- Drop and recreate optimized policies for TICKET_NOTES
DROP POLICY IF EXISTS "Users can view notes for accessible tickets" ON public.ticket_notes;
CREATE POLICY "Users can view notes for accessible tickets"
  ON public.ticket_notes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.tickets
      WHERE tickets.id = ticket_notes.ticket_id
      AND (
        tickets.assigned_to = (SELECT auth.uid()) OR
        tickets.created_by = (SELECT auth.uid()) OR
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE profiles.id = (SELECT auth.uid())
          AND profiles.role IN ('admin', 'dispatcher')
        )
      )
    )
  );

DROP POLICY IF EXISTS "Users can create notes on accessible tickets" ON public.ticket_notes;
CREATE POLICY "Users can create notes on accessible tickets"
  ON public.ticket_notes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tickets
      WHERE tickets.id = ticket_notes.ticket_id
      AND (
        tickets.assigned_to = (SELECT auth.uid()) OR
        tickets.created_by = (SELECT auth.uid()) OR
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE profiles.id = (SELECT auth.uid())
          AND profiles.role IN ('admin', 'dispatcher')
        )
      )
    )
  );

-- Drop and recreate optimized policies for TICKET_PHOTOS
DROP POLICY IF EXISTS "Users can view photos for accessible tickets" ON public.ticket_photos;
CREATE POLICY "Users can view photos for accessible tickets"
  ON public.ticket_photos
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.tickets
      WHERE tickets.id = ticket_photos.ticket_id
      AND (
        tickets.assigned_to = (SELECT auth.uid()) OR
        tickets.created_by = (SELECT auth.uid()) OR
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE profiles.id = (SELECT auth.uid())
          AND profiles.role IN ('admin', 'dispatcher')
        )
      )
    )
  );

DROP POLICY IF EXISTS "Users can upload photos to accessible tickets" ON public.ticket_photos;
CREATE POLICY "Users can upload photos to accessible tickets"
  ON public.ticket_photos
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tickets
      WHERE tickets.id = ticket_photos.ticket_id
      AND (
        tickets.assigned_to = (SELECT auth.uid()) OR
        tickets.created_by = (SELECT auth.uid()) OR
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE profiles.id = (SELECT auth.uid())
          AND profiles.role IN ('admin', 'dispatcher')
        )
      )
    )
  );

-- Drop and recreate optimized policies for PARTS_USAGE
DROP POLICY IF EXISTS "Users can view parts usage for accessible tickets" ON public.parts_usage;
CREATE POLICY "Users can view parts usage for accessible tickets"
  ON public.parts_usage
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.tickets
      WHERE tickets.id = parts_usage.ticket_id
      AND (
        tickets.assigned_to = (SELECT auth.uid()) OR
        tickets.created_by = (SELECT auth.uid()) OR
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE profiles.id = (SELECT auth.uid())
          AND profiles.role IN ('admin', 'dispatcher')
        )
      )
    )
  );

DROP POLICY IF EXISTS "Users can record parts usage on accessible tickets" ON public.parts_usage;
CREATE POLICY "Users can record parts usage on accessible tickets"
  ON public.parts_usage
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.tickets
      WHERE tickets.id = parts_usage.ticket_id
      AND (
        tickets.assigned_to = (SELECT auth.uid()) OR
        tickets.created_by = (SELECT auth.uid()) OR
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE profiles.id = (SELECT auth.uid())
          AND profiles.role IN ('admin', 'dispatcher')
        )
      )
    )
  );

-- Drop and recreate optimized policies for TECHNICIAN_LOCATIONS
DROP POLICY IF EXISTS "Admins and dispatchers can view all technician locations" ON public.technician_locations;
CREATE POLICY "Admins and dispatchers can view all technician locations"
  ON public.technician_locations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = (SELECT auth.uid())
      AND profiles.role IN ('admin', 'dispatcher')
    )
  );

DROP POLICY IF EXISTS "Technicians can view own location history" ON public.technician_locations;
CREATE POLICY "Technicians can view own location history"
  ON public.technician_locations
  FOR SELECT
  TO authenticated
  USING (technician_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Technicians can insert own location" ON public.technician_locations;
CREATE POLICY "Technicians can insert own location"
  ON public.technician_locations
  FOR INSERT
  TO authenticated
  WITH CHECK (technician_id = (SELECT auth.uid()));
