/*
  # Ticket-Invoice Integration - Part 4: Reporting Views

  ## Overview
  Creates views for reporting on ticket revenue, billing timing, and workflow status.

  ## Changes
  1. View for tickets ready to invoice
  2. View for ticket revenue summary
  3. View for project revenue rollup
  4. View for billing performance metrics
  5. View for invoice traceability
*/

-- =====================================================
-- 1. View: Tickets Ready to Invoice
-- =====================================================

CREATE OR REPLACE VIEW tickets_ready_to_invoice AS
SELECT 
  t.id,
  t.ticket_number,
  t.ticket_type,
  t.title,
  t.description,
  t.status,
  t.customer_id,
  t.site_id,
  t.project_id,
  t.completed_at,
  t.ready_to_invoice_at,
  c.name as customer_name,
  c.email as customer_email,
  c.phone as customer_phone,
  p.full_name as assigned_technician,
  p.email as technician_email,
  EXTRACT(DAY FROM (now() - t.completed_at))::integer as days_since_completion,
  EXTRACT(DAY FROM (now() - t.ready_to_invoice_at))::integer as days_waiting_to_invoice,
  -- Count time logs and total hours
  (SELECT COUNT(*) FROM time_logs tl WHERE tl.ticket_id = t.id) as time_log_count,
  (SELECT SUM(tl.total_hours) FROM time_logs tl WHERE tl.ticket_id = t.id) as total_hours
FROM tickets t
LEFT JOIN customers c ON c.id = t.customer_id
LEFT JOIN profiles p ON p.id = t.assigned_to
WHERE t.status = 'ready_to_invoice'
  AND t.billable = true
  AND t.invoice_id IS NULL
ORDER BY t.ready_to_invoice_at ASC NULLS LAST, t.completed_at ASC;

COMMENT ON VIEW tickets_ready_to_invoice IS 'All billable tickets ready to be invoiced with aging and resource information';

-- =====================================================
-- 2. View: Ticket Revenue Summary
-- =====================================================

CREATE OR REPLACE VIEW ticket_revenue_summary AS
SELECT 
  t.id as ticket_id,
  t.ticket_number,
  t.ticket_type,
  t.title,
  t.customer_id,
  t.project_id,
  t.status,
  t.billable,
  t.billed_amount,
  t.completed_at,
  t.ready_to_invoice_at,
  t.billed_at,
  CASE 
    WHEN t.billed_at IS NOT NULL AND t.completed_at IS NOT NULL 
    THEN EXTRACT(DAY FROM (t.billed_at - t.completed_at))::integer
    ELSE NULL
  END as days_to_bill,
  CASE 
    WHEN t.billed_at IS NOT NULL AND t.ready_to_invoice_at IS NOT NULL 
    THEN EXTRACT(DAY FROM (t.billed_at - t.ready_to_invoice_at))::integer
    ELSE NULL
  END as days_from_ready_to_billed,
  COUNT(DISTINCT i.id) as invoice_count,
  STRING_AGG(DISTINCT i.invoice_number, ', ' ORDER BY i.invoice_number) as invoice_numbers,
  SUM(ili.line_total) FILTER (WHERE ili.item_type = 'labor') as labor_revenue,
  SUM(ili.line_total) FILTER (WHERE ili.item_type = 'part') as parts_revenue,
  SUM(ili.line_total) FILTER (WHERE ili.item_type = 'service') as service_revenue,
  SUM(ili.line_total) FILTER (WHERE ili.item_type = 'travel') as travel_revenue,
  -- Calculate labor hours and cost
  (SELECT SUM(tl.total_hours) FROM time_logs tl WHERE tl.ticket_id = t.id) as total_labor_hours,
  (SELECT SUM(tl.total_cost_amount) FROM time_logs tl WHERE tl.ticket_id = t.id) as total_labor_cost,
  -- Margin calculation (revenue - cost)
  t.billed_amount - COALESCE((SELECT SUM(tl.total_cost_amount) FROM time_logs tl WHERE tl.ticket_id = t.id), 0) as gross_margin
FROM tickets t
LEFT JOIN invoices i ON (i.ticket_id = t.id OR i.source_ticket_id = t.id) AND i.status NOT IN ('cancelled', 'written_off')
LEFT JOIN invoice_line_items ili ON ili.invoice_id = i.id AND ili.ticket_id = t.id
WHERE t.billable = true
GROUP BY t.id, t.ticket_number, t.ticket_type, t.title, t.customer_id, t.project_id, 
         t.status, t.billable, t.billed_amount, t.completed_at, t.ready_to_invoice_at, t.billed_at;

COMMENT ON VIEW ticket_revenue_summary IS 'Revenue breakdown by ticket showing labor/parts/service split, costs, margins, and billing timing';

-- =====================================================
-- 3. View: Project Revenue Rollup
-- =====================================================

CREATE OR REPLACE VIEW project_revenue_rollup AS
SELECT 
  pr.id as project_id,
  pr.name as project_name,
  pr.project_number,
  pr.customer_id,
  pr.status as project_status,
  c.name as customer_name,
  COUNT(DISTINCT t.id) as ticket_count,
  COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'closed_billed') as billed_ticket_count,
  COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'ready_to_invoice') as ready_to_invoice_count,
  SUM(t.billed_amount) as total_billed_amount,
  SUM(t.billed_amount) FILTER (WHERE t.ticket_type = 'SVC') as svc_billed_amount,
  SUM(t.billed_amount) FILTER (WHERE t.ticket_type = 'PRJ') as prj_billed_amount,
  -- Time and labor
  SUM((SELECT SUM(tl.total_hours) FROM time_logs tl WHERE tl.ticket_id = t.id)) as total_labor_hours,
  SUM((SELECT SUM(tl.total_cost_amount) FROM time_logs tl WHERE tl.ticket_id = t.id)) as total_labor_cost,
  -- Margin
  SUM(t.billed_amount) - COALESCE(SUM((SELECT SUM(tl.total_cost_amount) FROM time_logs tl WHERE tl.ticket_id = t.id)), 0) as gross_margin,
  CASE 
    WHEN SUM(t.billed_amount) > 0 
    THEN ((SUM(t.billed_amount) - COALESCE(SUM((SELECT SUM(tl.total_cost_amount) FROM time_logs tl WHERE tl.ticket_id = t.id)), 0)) / SUM(t.billed_amount) * 100)
    ELSE 0
  END as margin_percentage
FROM projects pr
LEFT JOIN tickets t ON t.project_id = pr.id AND t.billable = true
LEFT JOIN customers c ON c.id = pr.customer_id
GROUP BY pr.id, pr.name, pr.project_number, pr.customer_id, pr.status, c.name;

COMMENT ON VIEW project_revenue_rollup IS 'Revenue, costs, and margins rolled up by project including all associated tickets';

-- =====================================================
-- 4. View: Billing Performance Metrics
-- =====================================================

CREATE OR REPLACE VIEW billing_performance_metrics AS
SELECT 
  DATE_TRUNC('month', t.billed_at) as billing_month,
  COUNT(DISTINCT t.id) as tickets_billed,
  SUM(t.billed_amount) as total_revenue,
  AVG(EXTRACT(DAY FROM (t.billed_at - t.completed_at))) as avg_days_to_bill,
  AVG(EXTRACT(DAY FROM (t.billed_at - t.ready_to_invoice_at))) as avg_days_from_ready_to_billed,
  SUM(t.billed_amount) FILTER (WHERE t.ticket_type = 'SVC') as svc_revenue,
  SUM(t.billed_amount) FILTER (WHERE t.ticket_type = 'PRJ') as prj_revenue,
  COUNT(DISTINCT t.id) FILTER (WHERE t.ticket_type = 'SVC') as svc_ticket_count,
  COUNT(DISTINCT t.id) FILTER (WHERE t.ticket_type = 'PRJ') as prj_ticket_count,
  -- Payment performance
  COUNT(DISTINCT i.id) FILTER (WHERE i.status = 'paid') as invoices_paid,
  COUNT(DISTINCT i.id) FILTER (WHERE i.status = 'partially_paid') as invoices_partial,
  COUNT(DISTINCT i.id) FILTER (WHERE i.status = 'overdue') as invoices_overdue,
  AVG((i.paid_date - i.issue_date)) FILTER (WHERE i.paid_date IS NOT NULL) as avg_days_to_payment
FROM tickets t
LEFT JOIN invoices i ON (i.ticket_id = t.id OR i.source_ticket_id = t.id)
WHERE t.status = 'closed_billed'
  AND t.billable = true
  AND t.billed_at IS NOT NULL
GROUP BY DATE_TRUNC('month', t.billed_at)
ORDER BY billing_month DESC;

COMMENT ON VIEW billing_performance_metrics IS 'Monthly billing performance showing revenue, timing metrics, and payment status';

-- =====================================================
-- 5. View: Invoice Traceability Report
-- =====================================================

CREATE OR REPLACE VIEW invoice_traceability_report AS
SELECT 
  i.id as invoice_id,
  i.invoice_number,
  i.customer_id,
  c.name as customer_name,
  i.source_type,
  i.status as invoice_status,
  i.issue_date,
  i.due_date,
  i.paid_date,
  i.total_amount,
  i.amount_paid,
  i.balance_due,
  -- Primary ticket link
  i.ticket_id as primary_ticket_id,
  t1.ticket_number as primary_ticket_number,
  i.source_ticket_id,
  t2.ticket_number as source_ticket_number,
  -- All linked tickets via many-to-many
  (
    SELECT json_agg(json_build_object(
      'ticket_id', til.ticket_id,
      'ticket_number', t3.ticket_number,
      'ticket_type', t3.ticket_type,
      'amount_contributed', til.amount_contributed
    ))
    FROM ticket_invoice_links til
    JOIN tickets t3 ON t3.id = til.ticket_id
    WHERE til.invoice_id = i.id
  ) as linked_tickets,
  -- Project link
  i.project_id,
  pr.project_number,
  pr.name as project_name
FROM invoices i
LEFT JOIN customers c ON c.id = i.customer_id
LEFT JOIN tickets t1 ON t1.id = i.ticket_id
LEFT JOIN tickets t2 ON t2.id = i.source_ticket_id
LEFT JOIN projects pr ON pr.id = i.project_id;

COMMENT ON VIEW invoice_traceability_report IS 'Complete traceability showing which tickets contributed to each invoice';
