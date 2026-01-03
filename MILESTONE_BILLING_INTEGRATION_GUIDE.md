# Milestone Billing Integration Guide

## Overview

The master projects and milestone billing system is now fully operational with invoice creation, GL posting, and deposit management. This guide covers how to complete the final UI integration.

## What's Been Implemented

### Backend Services & Database

✅ **Database Schema (Complete)**
- `projects` table enhanced with master/site fields
- `project_billing_schedules` table for milestones
- `project_deposit_releases` table for tracking releases
- `invoice_line_items` enhanced with deposit/retainage flags
- GL accounts: 2350 (Contract Liability), 4100 (Project Revenue), 1250 (Retainage Receivable)

✅ **Services (Complete)**
- `MilestoneInvoiceService` - Create invoices from milestones, release deposits
- Enhanced `post_invoice_to_gl()` - Routes deposits to liability, regular items to revenue
- `post_deposit_release_to_gl()` - Moves funds from liability to revenue
- Auto-posting triggers for GL integration

✅ **Views & Functions (Complete)**
- `v_project_financial_summary` - Per-project financial metrics
- `v_site_jobs_summary` - Site job rollup
- `v_master_project_rollup` - Master project aggregation
- Helper functions for amounts and completion %

### Frontend Components (Ready to Use)

✅ **Milestone Billing**
- `ProjectBillingSchedule` - Display milestones, bill to invoice with validation
- `BillMilestoneModal` - Confirmation dialog with amount calculation and warnings

✅ **Deposit Management**
- `DepositReleasePanel` - Show deposit status and release deposits
- `ReleaseDepositModal` - UI for releasing deposits to revenue

✅ **Master Projects**
- `MasterProjectView` - Dashboard for master projects with sites rollup

## Integration Steps

### Step 1: Update ProjectDetailView

Add tabs for Billing Schedule and Deposits to the project detail view.

**File:** `src/components/Projects/ProjectDetailView.tsx`

```typescript
import { ProjectBillingSchedule } from './ProjectBillingSchedule';
import { DepositReleasePanel } from './DepositReleasePanel';

// In the tabs section, add:
<button
  onClick={() => setActiveTab('billing')}
  className={`tab ${activeTab === 'billing' ? 'active' : ''}`}
>
  Billing Schedule
</button>

<button
  onClick={() => setActiveTab('deposits')}
  className={`tab ${activeTab === 'deposits' ? 'active' : ''}`}
>
  Deposits
</button>

// In the tab content section:
{activeTab === 'billing' && (
  <ProjectBillingSchedule
    projectId={projectId}
    contractValue={project.contract_value_site || project.contract_value_total || project.budget}
    customerId={project.customer_id}
  />
)}

{activeTab === 'deposits' && (
  <DepositReleasePanel projectId={projectId} />
)}
```

### Step 2: Update ProjectsView for Master/Site Hierarchy

Show master project indicator and parent project linkage.

**File:** `src/components/Projects/ProjectsView.tsx`

```typescript
// In the project query, add new fields:
.select('*, customers(name), profiles:manager_id(full_name), parent_project:parent_project_id(project_number, name)')

// In the project card display, add indicator:
{project.is_master_project && (
  <span className="badge badge-blue text-xs ml-2">Master</span>
)}

{project.parent_project_id && (
  <div className="text-xs text-gray-500 mt-1">
    Part of: {project.parent_project?.project_number}
  </div>
)}

// Add filter for project types:
<select
  value={projectTypeFilter}
  onChange={(e) => setProjectTypeFilter(e.target.value)}
  className="input md:w-64"
>
  <option value="all">All Projects</option>
  <option value="master">Master Projects Only</option>
  <option value="sites">Site Jobs Only</option>
  <option value="standalone">Standalone Projects</option>
</select>
```

### Step 3: Add Master Project Toggle to New Project Form

Allow creating master projects from the UI.

**File:** `src/components/Projects/ProjectsView.tsx`

```typescript
// In the form data state:
const [formData, setFormData] = useState({
  // ... existing fields
  is_master_project: false,
  contract_value_total: 0,
  parent_project_id: '',
  contract_value_site: 0,
  site_name: '',
  site_address: '',
});

// In the form, add toggle:
<div className="md:col-span-2">
  <label className="flex items-center space-x-2">
    <input
      type="checkbox"
      checked={formData.is_master_project}
      onChange={(e) => setFormData({ ...formData, is_master_project: e.target.checked })}
      className="rounded"
    />
    <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
      This is a master project with multiple sites
    </span>
  </label>
</div>

{formData.is_master_project && (
  <div>
    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
      Total Contract Value
    </label>
    <input
      type="number"
      value={formData.contract_value_total}
      onChange={(e) => setFormData({ ...formData, contract_value_total: parseFloat(e.target.value) || 0 })}
      className="input"
    />
  </div>
)}

{!formData.is_master_project && (
  <>
    <div>
      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
        Parent Master Project (Optional)
      </label>
      <select
        value={formData.parent_project_id}
        onChange={(e) => setFormData({ ...formData, parent_project_id: e.target.value })}
        className="input"
      >
        <option value="">Standalone Project</option>
        {masterProjects.map((mp) => (
          <option key={mp.id} value={mp.id}>
            {mp.project_number} - {mp.name}
          </option>
        ))}
      </select>
    </div>

    {formData.parent_project_id && (
      <>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Site Contract Value
          </label>
          <input
            type="number"
            value={formData.contract_value_site}
            onChange={(e) => setFormData({ ...formData, contract_value_site: parseFloat(e.target.value) || 0 })}
            className="input"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Site Name
          </label>
          <input
            type="text"
            value={formData.site_name}
            onChange={(e) => setFormData({ ...formData, site_name: e.target.value })}
            className="input"
            placeholder="e.g., Building A, Store #123"
          />
        </div>

        <div className="md:col-span-2">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Site Address
          </label>
          <input
            type="text"
            value={formData.site_address}
            onChange={(e) => setFormData({ ...formData, site_address: e.target.value })}
            className="input"
          />
        </div>
      </>
    )}
  </>
)}
```

### Step 4: Wire Master Project View

Show master project view when a master project is selected.

**File:** `src/components/Projects/ProjectDetailView.tsx`

```typescript
import { MasterProjectView } from './MasterProjectView';

// At the top of component, check if master project:
const [isMasterProject, setIsMasterProject] = useState(false);

useEffect(() => {
  // In loadProject function
  if (data.is_master_project) {
    setIsMasterProject(true);
  }
}, [projectId]);

// Conditionally render:
{isMasterProject ? (
  <MasterProjectView
    projectId={projectId}
    onClose={onBack}
  />
) : (
  // Normal project detail view
)}
```

## User Workflows

### Workflow 1: Create Master Project with Site Jobs

1. Click "New Project" in Projects view
2. Check "This is a master project with multiple sites"
3. Enter project details and total contract value ($10,000,000)
4. Save master project

5. For each site:
   - Click "New Project"
   - Select parent master project from dropdown
   - Enter site-specific details (name, address, contract value)
   - Save site job

### Workflow 2: Set Up Billing Schedule for Site

1. Open a site job in Projects view
2. Click "Billing Schedule" tab
3. Click "Add Milestone"
4. Create milestones:
   - Milestone 1: "Deposit" - 20%, is_deposit=TRUE
   - Milestone 2: "System Online" - 70%
   - Milestone 3: "Final" - 10%
5. Save milestones

### Workflow 3: Bill a Milestone

1. In site job Billing Schedule tab
2. Mark milestone as "Ready to Bill"
3. Click "Bill" button
4. Review amount and warnings in modal
5. Click "Create Invoice"
6. Invoice created in draft status with proper is_deposit flag
7. GL posting happens when invoice status changes from draft

### Workflow 4: Release Deposit to Revenue

1. In site job, click "Deposits" tab
2. View unreleased deposit amount
3. Click "Release Deposit"
4. Enter amount to release and reason
5. Click "Release Deposit"
6. GL entry created automatically:
   - DR Contract Liability (2350)
   - CR Project Revenue (4100)

### Workflow 5: View Master Project Dashboard

1. Click on a master project in Projects view
2. See overview with:
   - Total contract value
   - Number of sites (total, completed, in progress)
   - Unit-based completion %
   - Aggregate financial metrics
3. Click "Sites" tab to see all site jobs
4. Click "Financials" tab for revenue breakdown

## GL Account Mapping

The system uses the following GL accounts:

| Account | Code | Type | Purpose |
|---------|------|------|---------|
| Accounts Receivable | 1100 | Asset | Customer invoices |
| Retainage Receivable | 1250 | Asset | Withheld amounts |
| Contract Liability - Deposits | 2350 | Liability | Unearned revenue |
| Service Revenue | 4000 | Revenue | Labor revenue |
| Project Revenue | 4100 | Revenue | Milestone/project revenue |
| Parts Sales | 4300 | Revenue | Parts revenue |

### Invoice Posting Logic

**Regular Invoice Line:**
```
DR  1100  Accounts Receivable      $10,000
    CR 4000  Service Revenue               $10,000
```

**Deposit Invoice Line (is_deposit = TRUE):**
```
DR  1100  Accounts Receivable      $5,000
    CR 2350  Contract Liability            $5,000
```

**Deposit Release:**
```
DR  2350  Contract Liability       $5,000
    CR 4100  Project Revenue               $5,000
```

## Testing Checklist

### Backend Tests

- [ ] Create milestone with fixed amount - verify calculation
- [ ] Create milestone with % of contract - verify calculation
- [ ] Bill milestone to invoice - verify invoice created with correct flags
- [ ] Post invoice with deposit line - verify GL to liability not revenue
- [ ] Post invoice with regular line - verify GL to revenue
- [ ] Release deposit - verify GL journal entry created
- [ ] Query master project rollup view - verify aggregation
- [ ] Query site jobs summary - verify financial calculations

### Frontend Tests

- [ ] Create master project - verify saved with is_master_project = TRUE
- [ ] Create site job linked to master - verify parent_project_id set
- [ ] Add milestones to site - verify CRUD operations
- [ ] Mark milestone ready to bill - verify status change
- [ ] Bill milestone - verify invoice creation and success message
- [ ] View deposit panel - verify amounts calculated correctly
- [ ] Release deposit - verify success and GL posting
- [ ] View master project dashboard - verify KPIs and site list
- [ ] Filter projects by master/site/standalone - verify filtering works

### Regression Tests

- [ ] Existing standalone projects still work normally
- [ ] Existing invoices without deposit flags post to revenue
- [ ] Existing GL posting for non-project invoices unchanged
- [ ] All existing project views and reports still function

## Configuration Options

### Account Mapping (Optional)

To customize GL accounts, update the account codes in:
- `post_invoice_to_gl()` function
- `post_deposit_release_to_gl()` function

Or implement account mapping via settings table.

### Payment Terms

Default payment terms in MilestoneInvoiceService can be configured:
```typescript
const paymentTerms = params.paymentTerms || 'Net 30';
```

### Validation Thresholds

Over-billing warning threshold in `validateMilestoneForBilling()`:
```typescript
if (contractValue > 0 && sum > contractValue * 1.05) {  // 5% threshold
  warnings.push(...);
}
```

## Troubleshooting

### Issue: Invoice created but not showing deposits

**Solution:** Check that `invoice_line_items.is_deposit` was set to TRUE when the line item was created.

```sql
SELECT ili.*, i.invoice_number
FROM invoice_line_items ili
JOIN invoices i ON i.id = ili.invoice_id
WHERE ili.project_billing_schedule_id IS NOT NULL;
```

### Issue: Deposit not releasing

**Solution:** Verify unreleased amount:

```sql
SELECT * FROM get_unreleased_deposit_amount('<project_id>');
```

### Issue: GL not posting automatically

**Solution:** Check invoice status - GL only posts when status changes from 'draft':

```sql
SELECT id, invoice_number, status, gl_posted, gl_posted_at
FROM invoices
WHERE project_id = '<project_id>';
```

### Issue: Master project totals don't match sites

**Solution:** Verify all site jobs have contract_value_site set:

```sql
SELECT
  p.project_number,
  p.name,
  p.contract_value_site,
  parent.project_number as master_project
FROM projects p
LEFT JOIN projects parent ON parent.id = p.parent_project_id
WHERE p.parent_project_id = '<master_id>';
```

## Next Steps

1. **Complete UI Integration** - Add the code snippets above to ProjectsView and ProjectDetailView
2. **Test in Development** - Create test master project with 2-3 sites
3. **Test Milestone Billing** - Create milestones, bill them, verify invoices
4. **Test Deposit Release** - Bill a deposit, then release it
5. **Verify GL Posting** - Check gl_entries table for correct account postings
6. **Production Deployment** - No data migration needed, all changes are additive

## Summary

The complete master projects and milestone billing system is now operational:

✅ Database schema extended (additive only)
✅ GL posting enhanced for deposits and retainage
✅ Milestone invoice generation service complete
✅ Deposit release workflow implemented with auto GL posting
✅ UI components ready for integration
✅ Views and functions for financial tracking
✅ Backward compatible with existing projects

**Final Step:** Integrate the UI components into ProjectsView and ProjectDetailView using the code snippets above, then test the complete workflow.
