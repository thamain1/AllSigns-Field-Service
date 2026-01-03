/*
  # Add Missing Foreign Key Indexes for Performance Optimization

  This migration adds indexes to all foreign key columns that were previously unindexed,
  which will significantly improve query performance across the application.

  ## Performance Impact
  - Improves JOIN performance on foreign key relationships
  - Speeds up CASCADE operations on deletes/updates
  - Reduces query planning time for complex queries

  ## Tables Modified
  All tables with unindexed foreign keys receive new indexes covering those relationships.
*/

-- Accounting Settings
CREATE INDEX IF NOT EXISTS idx_accounting_settings_updated_by ON public.accounting_settings(updated_by);

-- Bank Reconciliations
CREATE INDEX IF NOT EXISTS idx_bank_reconciliations_reconciled_by ON public.bank_reconciliations(reconciled_by);

-- Chart of Accounts
CREATE INDEX IF NOT EXISTS idx_chart_of_accounts_parent_account_id ON public.chart_of_accounts(parent_account_id);

-- Customer Parts Installed
CREATE INDEX IF NOT EXISTS idx_customer_parts_installed_installed_by ON public.customer_parts_installed(installed_by);

-- Employee Deductions
CREATE INDEX IF NOT EXISTS idx_employee_deductions_deduction_id ON public.employee_deductions(deduction_id);

-- Estimate Activity Log
CREATE INDEX IF NOT EXISTS idx_estimate_activity_log_performed_by ON public.estimate_activity_log(performed_by);

-- Estimate Attachments
CREATE INDEX IF NOT EXISTS idx_estimate_attachments_uploaded_by ON public.estimate_attachments(uploaded_by);

-- Estimate Line Items
CREATE INDEX IF NOT EXISTS idx_estimate_line_items_equipment_id ON public.estimate_line_items(equipment_id);
CREATE INDEX IF NOT EXISTS idx_estimate_line_items_part_id ON public.estimate_line_items(part_id);

-- Estimates
CREATE INDEX IF NOT EXISTS idx_estimates_converted_to_project_id ON public.estimates(converted_to_project_id);
CREATE INDEX IF NOT EXISTS idx_estimates_converted_to_ticket_id ON public.estimates(converted_to_ticket_id);

-- GL Entries
CREATE INDEX IF NOT EXISTS idx_gl_entries_posted_by ON public.gl_entries(posted_by);

-- Inventory Balances
CREATE INDEX IF NOT EXISTS idx_inventory_balances_last_counted_by ON public.inventory_balances(last_counted_by);

-- Inventory Movements
CREATE INDEX IF NOT EXISTS idx_inventory_movements_from_location_id ON public.inventory_movements(from_location_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_moved_by ON public.inventory_movements(moved_by);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_po_id ON public.inventory_movements(po_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_project_id ON public.inventory_movements(project_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_ticket_id ON public.inventory_movements(ticket_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_to_location_id ON public.inventory_movements(to_location_id);

-- Invoice Line Items
CREATE INDEX IF NOT EXISTS idx_invoice_line_items_part_id ON public.invoice_line_items(part_id);

-- Invoices
CREATE INDEX IF NOT EXISTS idx_invoices_created_by ON public.invoices(created_by);

-- Part Installations
CREATE INDEX IF NOT EXISTS idx_part_installations_installed_by ON public.part_installations(installed_by);
CREATE INDEX IF NOT EXISTS idx_part_installations_removed_by ON public.part_installations(removed_by);
CREATE INDEX IF NOT EXISTS idx_part_installations_ticket_id ON public.part_installations(ticket_id);

-- Part Usage Log
CREATE INDEX IF NOT EXISTS idx_part_usage_log_from_location_id ON public.part_usage_log(from_location_id);
CREATE INDEX IF NOT EXISTS idx_part_usage_log_project_id ON public.part_usage_log(project_id);
CREATE INDEX IF NOT EXISTS idx_part_usage_log_serialized_part_id ON public.part_usage_log(serialized_part_id);
CREATE INDEX IF NOT EXISTS idx_part_usage_log_used_by ON public.part_usage_log(used_by);

-- Parts
CREATE INDEX IF NOT EXISTS idx_parts_preferred_vendor_id ON public.parts(preferred_vendor_id);

-- Parts Usage
CREATE INDEX IF NOT EXISTS idx_parts_usage_recorded_by ON public.parts_usage(recorded_by);

-- Payments
CREATE INDEX IF NOT EXISTS idx_payments_recorded_by ON public.payments(recorded_by);

-- Payroll Runs
CREATE INDEX IF NOT EXISTS idx_payroll_runs_approved_by ON public.payroll_runs(approved_by);
CREATE INDEX IF NOT EXISTS idx_payroll_runs_processed_by ON public.payroll_runs(processed_by);

-- Project Change Orders
CREATE INDEX IF NOT EXISTS idx_project_change_orders_approved_by ON public.project_change_orders(approved_by);
CREATE INDEX IF NOT EXISTS idx_project_change_orders_requested_by ON public.project_change_orders(requested_by);

-- Project Documents
CREATE INDEX IF NOT EXISTS idx_project_documents_uploaded_by ON public.project_documents(uploaded_by);

-- Project Issues
CREATE INDEX IF NOT EXISTS idx_project_issues_created_by ON public.project_issues(created_by);
CREATE INDEX IF NOT EXISTS idx_project_issues_task_id ON public.project_issues(task_id);

-- Project Template Phases
CREATE INDEX IF NOT EXISTS idx_project_template_phases_template_id ON public.project_template_phases(template_id);

-- Project Template Tasks
CREATE INDEX IF NOT EXISTS idx_project_template_tasks_template_phase_id ON public.project_template_tasks(template_phase_id);

-- Project Templates
CREATE INDEX IF NOT EXISTS idx_project_templates_created_by ON public.project_templates(created_by);

-- Projects
CREATE INDEX IF NOT EXISTS idx_projects_created_by ON public.projects(created_by);

-- Purchase Order Receipts
CREATE INDEX IF NOT EXISTS idx_purchase_order_receipts_po_id ON public.purchase_order_receipts(po_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_receipts_po_line_id ON public.purchase_order_receipts(po_line_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_receipts_received_at_location_id ON public.purchase_order_receipts(received_at_location_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_receipts_received_by ON public.purchase_order_receipts(received_by);

-- Purchase Orders
CREATE INDEX IF NOT EXISTS idx_purchase_orders_approved_by ON public.purchase_orders(approved_by);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_created_by ON public.purchase_orders(created_by);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_delivery_location_id ON public.purchase_orders(delivery_location_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_project_id ON public.purchase_orders(project_id);

-- Serialized Parts
CREATE INDEX IF NOT EXISTS idx_serialized_parts_installed_by ON public.serialized_parts(installed_by);
CREATE INDEX IF NOT EXISTS idx_serialized_parts_installed_on_ticket_id ON public.serialized_parts(installed_on_ticket_id);
CREATE INDEX IF NOT EXISTS idx_serialized_parts_po_line_id ON public.serialized_parts(po_line_id);
CREATE INDEX IF NOT EXISTS idx_serialized_parts_vendor_id ON public.serialized_parts(vendor_id);

-- Stock Locations
CREATE INDEX IF NOT EXISTS idx_stock_locations_parent_location_id ON public.stock_locations(parent_location_id);

-- Ticket Notes
CREATE INDEX IF NOT EXISTS idx_ticket_notes_created_by ON public.ticket_notes(created_by);

-- Ticket Photos
CREATE INDEX IF NOT EXISTS idx_ticket_photos_uploaded_by ON public.ticket_photos(uploaded_by);

-- Ticket Sequences
CREATE INDEX IF NOT EXISTS idx_ticket_sequences_project_id ON public.ticket_sequences(project_id);

-- Tickets
CREATE INDEX IF NOT EXISTS idx_tickets_created_by ON public.tickets(created_by);
CREATE INDEX IF NOT EXISTS idx_tickets_equipment_id ON public.tickets(equipment_id);
CREATE INDEX IF NOT EXISTS idx_tickets_invoice_id ON public.tickets(invoice_id);

-- Time Adjustments
CREATE INDEX IF NOT EXISTS idx_time_adjustments_adjusted_by ON public.time_adjustments(adjusted_by);

-- Time Logs
CREATE INDEX IF NOT EXISTS idx_time_logs_approved_by ON public.time_logs(approved_by);

-- Vendor Bills
CREATE INDEX IF NOT EXISTS idx_vendor_bills_created_by ON public.vendor_bills(created_by);

-- Warranty Claims
CREATE INDEX IF NOT EXISTS idx_warranty_claims_approved_by ON public.warranty_claims(approved_by);
CREATE INDEX IF NOT EXISTS idx_warranty_claims_serialized_part_id ON public.warranty_claims(serialized_part_id);
CREATE INDEX IF NOT EXISTS idx_warranty_claims_submitted_by ON public.warranty_claims(submitted_by);
CREATE INDEX IF NOT EXISTS idx_warranty_claims_ticket_id ON public.warranty_claims(ticket_id);
CREATE INDEX IF NOT EXISTS idx_warranty_claims_warranty_record_id ON public.warranty_claims(warranty_record_id);

-- Warranty Records
CREATE INDEX IF NOT EXISTS idx_warranty_records_vendor_id ON public.warranty_records(vendor_id);
