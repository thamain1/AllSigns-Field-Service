/*
  # Ticket-Invoice Integration - Part 1: Enum Extensions

  ## Overview
  Extends existing enums to support the new ticket-invoice workflow statuses.

  ## Changes
  1. Ticket Status: Add `ready_to_invoice`, `closed_billed`, `closed_no_charge`
  2. Invoice Status: Add `partially_paid`, `written_off`
  3. Create new `invoice_source_type` enum: SVC, PRJ, Mixed
*/

-- =====================================================
-- 1. Extend ticket_status enum
-- =====================================================

ALTER TYPE ticket_status ADD VALUE IF NOT EXISTS 'ready_to_invoice';
ALTER TYPE ticket_status ADD VALUE IF NOT EXISTS 'closed_billed';
ALTER TYPE ticket_status ADD VALUE IF NOT EXISTS 'closed_no_charge';

-- =====================================================
-- 2. Extend invoice_status enum
-- =====================================================

ALTER TYPE invoice_status ADD VALUE IF NOT EXISTS 'partially_paid';
ALTER TYPE invoice_status ADD VALUE IF NOT EXISTS 'written_off';

-- =====================================================
-- 3. Create source_type enum for invoices
-- =====================================================

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_source_type') THEN
    CREATE TYPE invoice_source_type AS ENUM ('SVC', 'PRJ', 'Mixed');
  END IF;
END $$;
