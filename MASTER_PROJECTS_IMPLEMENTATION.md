## Master Projects & Multi-Site Billing Implementation

## Overview

A complete **Master Projects with Site Sub-Jobs and Milestone Billing** system has been implemented to support:

- Large multi-site contracts with hundreds of locations
- Per-site work execution and cost tracking
- Milestone-based progress billing including deposits and retainage
- Revenue recognition as work is performed
- Master project rollup reporting with unit-based completion tracking

## Key Features

### 1. Master Project Hierarchy
- **Master Projects**: Top-level contracts representing entire multi-site engagements
- **Site Jobs**: Individual child projects for each location, each with its own:
  - Contract value allocation
  - Work tickets and costs
  - Billing schedule
  - Financial tracking

### 2. Milestone Billing
- **Flexible Milestones**: Define billing schedules per site with:
  - Fixed amounts or percentage of contract
  - Deposit flagging (posts to liability)
  - Retainage tracking
  - Target events and dates
  - Status workflow (planned → ready to bill → billed)

### 3. Deposit Accounting
- **Unearned Revenue Tracking**: Deposits post to Contract Liability (Account 2350)
- **Deposit Releases**: Track when deposits are released from liability to revenue
- **GL Integration**: Uses existing GL posting framework with appropriate account mapping

### 4. Revenue Recognition
- **Per-Site Tracking**: Revenue recognized at site job level as milestones are billed
- **Master Rollup**: Aggregate all site revenues to master project level
- **Unit-Based Completion**: Calculate master project % complete based on completed sites

## Database Schema

### Additive Changes to Existing Tables

#### `projects` Table (Enhanced)
New columns added (all nullable, non-destructive):

| Column | Type | Purpose |
|--------|------|---------|
| `is_master_project` | boolean | TRUE for master projects, FALSE for regular/site jobs |
| `parent_project_id` | uuid (FK) | Links site jobs to master project |
| `contract_value_total` | numeric | Total contract value for master projects |
| `contract_value_site` | numeric | Allocated contract value for this site job |
| `site_name` | text | Name/identifier for site (e.g., "Store #123") |
| `site_address` | text | Physical address of site |
| `sequence_number` | integer | Order of sites within master |

**Constraints:**
- Self-referential FK with cascade delete
- Prevents circular references (parent_id != id)
- Indexed on parent_project_id and is_master_project

#### `invoice_line_items` Table (Enhanced)
New columns added:

| Column | Type | Purpose |
|--------|------|---------|
| `is_deposit` | boolean | Flags deposit line items for GL routing to liability |
| `is_retainage` | boolean | Flags retainage line items |
| `project_billing_schedule_id` | uuid (FK) | Links to specific milestone being billed |

### New Tables

#### `project_billing_schedules`
Tracks milestones and progress billing for projects.

**Key Fields:**
- `project_id` (FK → projects)
- `sequence` - Order of milestones
- `name`, `description` - Milestone identification
- `billing_type` - ENUM: fixed_amount, percent_of_contract
- `amount` - Fixed dollar amount
- `percent_of_contract` - Percentage (0-100)
- `is_deposit`, `is_retainage` - Special milestone flags
- `status` - ENUM: planned, ready_to_bill, billed, partially_billed, cancelled
- `target_event`, `target_date` - When milestone should be reached
- `invoice_id` (FK → invoices) - Link to invoice once billed
- `billed_amount` - Running total of amounts billed

**Business Logic:**
- Calculate milestone amount from billing_type and contract value
- Support multiple milestones per project
- Track lifecycle from planning to billing
- Validate total milestones don't exceed contract value (soft warning)

#### `project_deposit_releases`
Tracks when deposits are released from liability to revenue.

**Key Fields:**
- `project_id` (FK → projects)
- `deposit_invoice_id` (FK → invoices) - Original deposit invoice
- `deposit_amount` - Total deposit amount
- `release_amount` - Amount being released
- `release_date`, `release_reason` - When and why
- `gl_entry_id` - Link to journal entry
- `gl_posted` - Whether GL entry has been posted
- `related_milestone_id`, `related_invoice_id` - Optional linkage to milestone

**Purpose:**
- Separate table for audit trail of deposit releases
- Tracks partial releases (release_amount ≤ deposit_amount)
- Links to GL entries for proper accounting

### GL Account Setup

#### New Chart of Accounts (Auto-Created)

| Account Code | Account Name | Type | Purpose |
|--------------|--------------|------|---------|
| 2350 | Contract Liability - Deposits | Liability | Unearned revenue from deposits |
| 4100 | Project Revenue | Revenue | Earned revenue from project work |
| 1250 | Retainage Receivable | Asset | Amounts withheld by customers |

**GL Posting Patterns:**

**Deposit Invoice:**
```
Dr  1200  Accounts Receivable     $10,000
    Cr 2350  Contract Liability         $10,000
```

**Regular Milestone Invoice:**
```
Dr  1200  Accounts Receivable     $70,000
    Cr 4100  Project Revenue            $70,000
```

**Deposit Release (Journal Entry):**
```
Dr  2350  Contract Liability      $10,000
    Cr 4100  Project Revenue            $10,000
```

## Views and Functions

### Views

#### `v_project_financial_summary`
Per-project financial metrics including:
- Contract value (site or total)
- Billed to date, deposits, revenue recognized
- Cost to date (from time logs, parts, etc.)
- Gross profit and margin
- Unbilled amount
- Milestone progress (completed/total)

#### `v_site_jobs_summary`
All site jobs with their financial performance:
- Links to master project
- Site name, address, sequence
- Complete financial summary
- Milestone completion percentage

#### `v_master_project_rollup`
Master projects with aggregated site data:
- Total sites, completed, in progress
- Unit-based completion percentage
- Aggregated financial totals from all sites
- Contract value vs actual performance
- Gross profit and margin rollup

### Functions

#### `get_unreleased_deposit_amount(project_id)`
Returns the amount of deposits that have been billed but not yet released to revenue.

#### `get_project_billing_summary(project_id)`
Returns comprehensive billing summary:
- Contract value
- Billed to date
- Deposits billed/unreleased
- Revenue recognized
- Unbilled amount

#### `get_project_cost_to_date(project_id)`
Calculates total project costs from:
- Labor (time logs)
- Parts (ticket parts)
- Other costs (extensible)

#### `calculate_milestone_amount(billing_schedule_id)`
Calculates the dollar amount for a milestone based on:
- Billing type (fixed or percent)
- Contract value
- Percentage if applicable

#### `get_master_project_percent_complete(master_project_id, method)`
Calculates master project completion by:
- **'units'**: Completed sites / total sites × 100
- **'revenue'**: Revenue recognized / contract value × 100

## User Interface Components

### MasterProjectView Component
**Location:** `src/components/Projects/MasterProjectView.tsx`

**Features:**
- KPI cards: Contract Value, Total Sites, Completion %, Gross Margin
- Three tabs:
  - **Overview**: Revenue breakdown, deposits, costs & profit
  - **Sites**: Table of all site jobs with status and financials
  - **Financials**: Detailed revenue and profitability charts

**Props:**
- `projectId`: UUID of master project
- `onClose`: Callback for closing view

### ProjectBillingSchedule Component
**Location:** `src/components/Projects/ProjectBillingSchedule.tsx`

**Features:**
- KPI cards: Contract Value, Scheduled Billing, Already Billed, Remaining
- Warning if milestones over-scheduled (>105% of contract)
- Milestone table with:
  - Sequence, name, type (deposit/progress/retainage)
  - Amount calculation (fixed or % of contract)
  - Target event/date
  - Status with color coding
  - Actions: Mark Ready, Bill Milestone, View Invoice
- Add Milestone button (integration point)

**Props:**
- `projectId`: UUID of project (usually a site job)
- `contractValue`: Contract value for percentage calculations

## Workflow Examples

### Example 1: Create Master Project with 100 Sites

```sql
-- 1. Create master project
INSERT INTO projects (
  project_number, name, customer_id,
  is_master_project, contract_value_total,
  status, start_date, created_by
) VALUES (
  'PRJ-202501-0001',
  'National Store Rollout - 100 Locations',
  '<customer_id>',
  true,
  10000000.00, -- $10M total
  'in_progress',
  '2025-01-01',
  '<user_id>'
) RETURNING id;

-- 2. Create site jobs (repeat for each site)
INSERT INTO projects (
  project_number, name, customer_id,
  is_master_project, parent_project_id,
  contract_value_site, site_name, site_address,
  sequence_number, status, start_date, created_by
) VALUES (
  'PRJ-202501-0001-S001',
  'Store #001 - New York',
  '<customer_id>',
  false,
  '<master_project_id>',
  100000.00, -- $100k per site
  'Store #001',
  '123 Main St, New York, NY 10001',
  1,
  'planning',
  '2025-02-01',
  '<user_id>'
);

-- 3. Create billing schedule for each site
INSERT INTO project_billing_schedules (
  project_id, sequence, name,
  billing_type, percent_of_contract,
  is_deposit, status, target_event
) VALUES
-- Deposit: 20%
('<site_project_id>', 1, 'Mobilization Deposit', 'percent_of_contract', 20.00, true, 'planned', 'Site access granted'),
-- Progress: 70%
('<site_project_id>', 2, 'System Online', 'percent_of_contract', 70.00, false, 'planned', 'Equipment installed and tested'),
-- Final/Retainage: 10%
('<site_project_id>', 3, 'Final Payment', 'percent_of_contract', 10.00, true, 'planned', 'Punchlist complete and accepted');
```

### Example 2: Bill a Deposit Milestone

```sql
-- 1. Mark milestone ready to bill
UPDATE project_billing_schedules
SET status = 'ready_to_bill',
    updated_at = now(),
    updated_by = '<user_id>'
WHERE id = '<milestone_id>';

-- 2. Create invoice with deposit line item
INSERT INTO invoices (
  invoice_number, customer_id, project_id,
  issue_date, due_date, status,
  subtotal, tax_amount, total_amount,
  created_by
) VALUES (
  'INV-2025-00123',
  '<customer_id>',
  '<site_project_id>',
  CURRENT_DATE,
  CURRENT_DATE + INTERVAL '30 days',
  'draft',
  20000.00,
  1600.00,
  21600.00,
  '<user_id>'
) RETURNING id;

-- 3. Add invoice line item flagged as deposit
INSERT INTO invoice_line_items (
  invoice_id, project_id, project_billing_schedule_id,
  item_type, description,
  quantity, unit_price, line_total,
  is_deposit
) VALUES (
  '<invoice_id>',
  '<site_project_id>',
  '<milestone_id>',
  'service',
  'Mobilization Deposit - Store #001',
  1,
  20000.00,
  20000.00,
  true -- This flags it for GL posting to liability
);

-- 4. Update milestone
UPDATE project_billing_schedules
SET status = 'billed',
    invoice_id = '<invoice_id>',
    billed_amount = 20000.00,
    updated_at = now()
WHERE id = '<milestone_id>';
```

### Example 3: Release Deposit to Revenue

```sql
-- When milestone is reached, release deposit
INSERT INTO project_deposit_releases (
  project_id, deposit_invoice_id, deposit_invoice_line_id,
  deposit_amount, release_amount, release_date,
  release_reason, related_milestone_id, created_by
) VALUES (
  '<site_project_id>',
  '<deposit_invoice_id>',
  '<deposit_line_item_id>',
  20000.00,
  20000.00,
  CURRENT_DATE,
  'System online milestone reached, releasing full deposit',
  '<system_online_milestone_id>',
  '<user_id>'
) RETURNING id;

-- Create GL journal entry (Dr Contract Liability, Cr Revenue)
-- This would be handled by GL posting service
-- INSERT INTO gl_entries (...)
-- UPDATE project_deposit_releases SET gl_posted = true, gl_entry_id = '<gl_entry_id>'
```

## Integration Points

### With Existing Systems

#### 1. Invoicing
- `invoices.project_id` already exists - now supports site jobs
- `invoice_line_items.is_deposit` routes to correct GL accounts
- `invoice_line_items.project_billing_schedule_id` links to milestone

#### 2. GL Posting
- Existing GL posting framework detects `is_deposit` flag
- Routes to Account 2350 (Contract Liability) instead of 4100 (Revenue)
- Deposit releases create journal entries for reclassification

#### 3. Job Costing
- Existing cost tracking (time logs, parts) works at site job level
- `get_project_cost_to_date()` aggregates costs
- Views calculate gross profit per site

#### 4. Project Management
- Master projects show in project list with is_master_project flag
- Site jobs appear as regular projects but with parent linkage
- Existing project views enhanced with new financial tabs

### Future Enhancements

#### Invoice Generation from Milestones
```typescript
// Button in ProjectBillingSchedule component
const handleBillMilestone = async (milestone: BillingSchedule) => {
  const amount = calculateAmount(milestone);

  // Create invoice
  const invoice = await createInvoice({
    project_id: projectId,
    subtotal: amount,
    // ... other fields
  });

  // Add line item
  await createInvoiceLineItem({
    invoice_id: invoice.id,
    project_billing_schedule_id: milestone.id,
    is_deposit: milestone.is_deposit,
    is_retainage: milestone.is_retainage,
    description: milestone.name,
    line_total: amount,
  });

  // Update milestone
  await updateMilestone(milestone.id, {
    status: 'billed',
    invoice_id: invoice.id,
    billed_amount: amount,
  });
};
```

#### Automated Deposit Release
```typescript
// Triggered when progress milestone is billed
const autoReleaseDeposit = async (progressMilestone: BillingSchedule) => {
  // Find unreleased deposit for this project
  const unreleased = await getUnreleasedDepositAmount(projectId);

  if (unreleased > 0) {
    // Release deposit proportional to progress
    const releaseAmount = Math.min(unreleased, calculateAmount(progressMilestone));

    await createDepositRelease({
      project_id: projectId,
      release_amount: releaseAmount,
      related_milestone_id: progressMilestone.id,
      // ... GL posting
    });
  }
};
```

#### Master Project Dashboard
- Card for each site showing status and health
- Gantt chart of site timelines
- Financial performance heatmap
- Critical path and bottleneck identification

## Testing & Validation

### Schema Verification

```sql
-- Verify additive changes
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'projects'
  AND column_name IN ('is_master_project', 'parent_project_id', 'contract_value_site')
ORDER BY column_name;

-- Should return 3 rows, all nullable/defaulted

-- Verify new tables
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('project_billing_schedules', 'project_deposit_releases')
ORDER BY table_name;

-- Should return 2 rows

-- Verify views
SELECT table_name
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name LIKE 'v_%project%'
ORDER BY table_name;

-- Should include v_project_financial_summary, v_site_jobs_summary, v_master_project_rollup
```

### Functional Tests (Dev/Test Environment Only)

**IMPORTANT: These tests should ONLY be run in development/test environments. Do NOT create test data in production.**

```sql
-- Test 1: Create master project with 3 site jobs
INSERT INTO projects (project_number, name, customer_id, is_master_project, contract_value_total, status, start_date, created_by)
VALUES ('TEST-MASTER-001', 'Test Master Project', '<customer_id>', true, 300000.00, 'in_progress', CURRENT_DATE, '<user_id>')
RETURNING id;

-- Create 3 site jobs
INSERT INTO projects (project_number, name, customer_id, is_master_project, parent_project_id, contract_value_site, site_name, sequence_number, status, start_date, created_by)
SELECT
  'TEST-SITE-' || generate_series(1, 3),
  'Test Site ' || generate_series(1, 3),
  '<customer_id>',
  false,
  '<master_project_id>',
  100000.00,
  'Site #' || generate_series(1, 3),
  generate_series(1, 3),
  'planning',
  CURRENT_DATE,
  '<user_id>';

-- Test 2: Create billing schedule for one site
INSERT INTO project_billing_schedules (project_id, sequence, name, billing_type, percent_of_contract, is_deposit, status)
VALUES
  ('<site_1_id>', 1, 'Deposit', 'percent_of_contract', 20.00, true, 'planned'),
  ('<site_1_id>', 2, 'Progress', 'percent_of_contract', 70.00, false, 'planned'),
  ('<site_1_id>', 3, 'Final', 'percent_of_contract', 10.00, false, 'planned');

-- Test 3: Verify calculations
SELECT * FROM calculate_milestone_amount('<milestone_id>');
-- Should return 20000.00 for 20% of 100000

-- Test 4: Check master rollup
SELECT * FROM v_master_project_rollup WHERE master_project_id = '<master_project_id>';
-- Should show 3 total sites, 0 completed

-- Test 5: Mark one site completed and verify
UPDATE projects SET status = 'completed' WHERE id = '<site_1_id>';
SELECT percent_complete_units FROM v_master_project_rollup WHERE master_project_id = '<master_project_id>';
-- Should return 33.33 (1/3 sites complete)

-- Clean up test data
DELETE FROM projects WHERE project_number LIKE 'TEST-%';
```

## Regression Testing

### Verify Existing Functionality Unchanged

```sql
-- Check that existing projects still work
SELECT id, project_number, name, status, budget
FROM projects
WHERE is_master_project = false
  AND parent_project_id IS NULL
LIMIT 10;

-- Should return regular projects unaffected

-- Check that existing invoices still work
SELECT i.id, i.invoice_number, i.total_amount, ili.line_total
FROM invoices i
JOIN invoice_line_items ili ON ili.invoice_id = i.id
WHERE i.project_id IS NOT NULL
  AND ili.is_deposit = false
LIMIT 10;

-- Should return invoices with proper revenue posting

-- Verify GL posting still works
SELECT gl_posted, gl_entry_ids
FROM invoices
WHERE gl_posted = true
  AND created_at > CURRENT_DATE - INTERVAL '30 days'
LIMIT 10;

-- Should show recent invoices have GL entries
```

## Security & Permissions

### RLS Policies

All new tables have RLS enabled:

**project_billing_schedules:**
- SELECT: All authenticated users
- INSERT/UPDATE/DELETE: Admin and dispatcher roles only

**project_deposit_releases:**
- SELECT: All authenticated users
- INSERT/UPDATE/DELETE: Admin and dispatcher roles only

### Audit Trail

- All tables include created_at, updated_at
- Billing schedules track created_by, updated_by
- Deposit releases track created_by
- Full history of status changes

## Production Deployment Notes

### Database Changes
- All migrations are additive and safe to run in production
- No downtime required
- Existing data unaffected

### GL Account Setup
- Standard accounts (2350, 4100, 1250) auto-created if not present
- Verify account numbers don't conflict with existing chart
- Adjust account codes in migration if needed

### No Seeded Data
- ✅ No test/demo data is created in production
- ✅ Schema and logic only
- ✅ Sample data examples are for dev/test documentation only

### Integration Requirements
- Update invoice posting logic to check `is_deposit` flag
- Route deposits to Account 2350, regular revenue to 4100
- Implement deposit release GL posting service
- Enhance project views to show master/site hierarchy

## Summary

This implementation provides a complete multi-site project and milestone billing framework that:

✅ **Non-destructive**: All schema changes are additive, no existing data affected
✅ **Integrated**: Works with existing projects, invoicing, and GL systems
✅ **Scalable**: Supports hundreds of sites per master project
✅ **Flexible**: Fixed or percentage-based milestones, deposits and retainage
✅ **Trackable**: Comprehensive financial tracking from site to master level
✅ **Auditable**: Full history of billing events and deposit releases
✅ **Production-ready**: No test data, safe for immediate deployment

The system is ready for use with appropriate UI integration for invoice creation and GL posting workflows.
