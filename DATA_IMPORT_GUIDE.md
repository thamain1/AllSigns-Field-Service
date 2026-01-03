# Data Import Framework - User Guide

## Overview

The Data Import Framework provides a safe, repeatable way to import existing data from your previous ERP system into Dunaway Heating & Cooling's platform. The system uses staging tables, validation, and audit trails to ensure data integrity.

## Features

### ✅ Non-Destructive Design
- All changes are additive - no existing tables are modified or dropped
- Data goes through staging tables before being committed
- Full rollback capability for any import batch
- Idempotent imports - re-running the same file won't create duplicates

### ✅ Supported Import Types

#### Phase 1 (Available Now):
- **Customers** - Import master customer data with contact information
- **Open AR** - Import accounts receivable aging to establish opening balances

#### Phase 2-3 (Coming Soon):
- Vendors
- Parts/Items
- Historical invoices and payments
- Service history

### ✅ Validation & Error Handling
- Pre-validation before any data is committed
- Required field checking
- Data type validation
- Currency normalization (handles $, commas, parentheses)
- Date parsing
- Duplicate detection
- Download error reports for fixing issues

### ✅ Column Mapping
- Auto-map columns based on common field names
- Manual override capability
- Preview sample values before importing
- Save mappings for future use

### ✅ Audit Trail
- Every import is tracked with a unique batch number
- Full audit log of all operations
- Track which import created each record
- Rollback entire batches if needed

## How to Use

### Step 1: Access Data Import
1. Log in as an **Admin** user
2. Navigate to **Administration → Data Import**
3. Click "New Import" to launch the wizard

### Step 2: Select Import Type
Choose what you want to import:
- **Customers** - For customer master data
- **Open AR** - For establishing opening AR balances

### Step 3: Upload File
1. Drag and drop your CSV/TSV file or click to browse
2. Supported formats: `.csv`, `.tsv`, `.txt`
3. The system will auto-detect:
   - Delimiter (comma, tab, semicolon)
   - Encoding (UTF-8, UTF-16)
   - Number of rows and columns

#### File Requirements:

**For Customers:**
- Required: Customer Name
- Optional: Email, Phone, Address, City, State, ZIP, External Customer ID, Notes

**For Open AR:**
- Required: Customer ID (or Name), Invoice Number, Balance Due
- Optional: Current amount, 1-30 days, 31-60 days, 61-90 days, 90+ days, Issue Date, Due Date

### Step 4: Map Columns
1. Review auto-mapped columns (pre-selected based on common naming)
2. Adjust mappings if needed using the dropdown menus
3. View sample values to verify correct mapping
4. Required fields must be mapped before continuing

### Step 5: Validate Data
1. System validates all rows against business rules
2. Review validation summary:
   - Total rows
   - Valid rows (will be imported)
   - Error rows (will be skipped)
3. Download error report if needed to fix issues in source file
4. Valid rows will proceed even if some rows have errors

### Step 6: Import
1. Click "Start Import" to begin processing
2. Wait for import to complete (don't close the window)
3. Review import summary:
   - Records created
   - Records updated
   - Records skipped
   - Errors encountered

## Special Handling

### AR Aging Files
The system automatically handles common AR aging file formats:

**Automatic Processing:**
- Skips "Total" rows and summary lines
- Normalizes currency values: `$1,234.56` → `1234.56`
- Handles negative values in parentheses: `($123.45)` → `-123.45`
- Strips commas, dollar signs, and extra spaces

**Matching Customers:**
- First tries to match by External Customer ID
- Falls back to name matching if no ID provided
- Creates new customers if no match found

**Invoice Creation:**
- Marks all imported invoices as "migrated opening balance"
- Sets appropriate status (open if balance > 0, paid if balance = 0)
- Can optionally create GL entries for opening AR balance

### Customer Files
**Duplicate Handling:**
- Matches on External Customer ID if provided
- Updates existing customer if found
- Creates new customer if no match
- Never creates duplicates with same External ID

## Managing Imports

### View Import History
1. Go to **Administration → Data Import**
2. See list of all import batches with:
   - Batch number
   - Entity type
   - File name
   - Status
   - Row counts
   - Import date

### Filter Imports
Use the filter dropdown to view imports by type:
- All Types
- Customers only
- AR only
- etc.

### Rollback an Import
**Important:** This permanently deletes all records created by that import batch.

1. Locate the completed import in the list
2. Click the trash icon in the Actions column
3. Confirm the rollback
4. All customers/invoices created by that import will be deleted
5. The batch status will change to "Rolled Back"

## Database Schema

### New Tables Created

#### `import_batches`
Tracks each import session with metadata and status.

#### `import_customers_staging`
Temporary staging for customer data before validation/import.

#### `import_ar_staging`
Temporary staging for AR data before validation/import.

#### `import_logs`
Detailed event logging for troubleshooting.

### Modified Tables (Additive Only)

#### `customers`
New columns:
- `external_customer_id` - ID from source system
- `import_batch_id` - Which import created this record
- `imported_at` - When it was imported

#### `invoices`
New columns:
- `external_invoice_number` - Invoice # from source system
- `is_migrated_opening_balance` - Marks imported AR (true/false)
- `is_historical` - Marks historical data (true/false)
- `import_batch_id` - Which import created this record
- `imported_at` - When it was imported

## Data Safety

### Before Import
- Data is loaded into staging tables
- Validation rules are applied
- You can review errors and fix them

### During Import
- Records are created in transactions
- Errors don't stop the entire import
- Audit logs track every operation

### After Import
- Full audit trail maintained
- Can rollback entire batch if needed
- Imported records are clearly marked
- No impact on existing records

## Tips for Success

### Prepare Your Files
1. **Remove header/footer rows** - Keep only column headers and data rows
2. **Clean data** - Fix obvious errors before importing
3. **Consistent formatting** - Use same date format throughout
4. **Test with small batch** - Import 10-20 rows first to verify mapping

### AR Aging Files
1. **Include Customer IDs** - Makes matching much more reliable
2. **Check totals** - Verify the import total matches your AR balance
3. **Review aging buckets** - Ensure amounts are in correct columns
4. **Have invoice dates** - Use a detailed receivables export if aging report lacks dates

### Customer Files
1. **Include External IDs** - Prevents duplicates on re-import
2. **Standardize addresses** - Clean up formatting before import
3. **Validate emails** - Fix malformed email addresses
4. **Phone numbers** - Use consistent format (e.g., 555-123-4567)

### Error Resolution
1. **Download error report** - Contains all rows with issues
2. **Fix in source file** - Correct the issues in your original CSV
3. **Re-import** - Upload the fixed file (system will skip duplicates)

## Troubleshooting

### File Won't Parse
- Check file encoding (try UTF-8 if UTF-16 fails)
- Verify delimiter (comma vs tab vs semicolon)
- Remove special characters from column headers
- Ensure file has actual data rows

### Validation Errors
- Review error messages for each row
- Check required fields are populated
- Verify data types (numbers in amount fields, valid dates)
- Fix in source file and re-upload

### Import Fails
- Check import logs for detailed error messages
- Verify you have admin permissions
- Ensure database connection is stable
- Contact support if issue persists

### Duplicate Records
- System prevents duplicates by External ID
- If seeing duplicates, check if External ID is mapped correctly
- Use rollback to remove incorrect import
- Re-import with corrected mapping

## Advanced Features

### Batch Processing
- Process large files (10,000+ rows) without timeout
- Progress tracking during import
- Resume capability if interrupted

### Custom Field Mapping
- Save mapping configurations
- Reuse mappings for similar files
- Override auto-detected mappings

### Data Transformation
- Automatic currency normalization
- Date format detection and conversion
- Trim whitespace and clean data
- Handle various encoding formats

## Future Enhancements

### Phase 2 (Planned)
- Vendor imports
- Parts/inventory imports
- AP opening balances
- GL trial balance import

### Phase 3 (Planned)
- Historical invoices (12-24 months)
- Historical payments
- Service ticket history
- Scheduled/recurring imports

## Support

For assistance with data imports:
1. Review this guide thoroughly
2. Check validation error messages
3. Download and review error reports
4. Contact your system administrator
5. Reference import batch number when reporting issues

## Best Practices

### Migration Strategy
1. **Start with customers** - Import customer master data first
2. **Then import AR** - Establish opening AR balances
3. **Verify totals** - Check AR total matches expected balance
4. **Test workflows** - Create a test invoice to verify everything works
5. **Import remaining data** - Vendors, parts, history (when available)

### Data Quality
1. **Clean before import** - Fix obvious issues in source system
2. **Validate after import** - Spot-check imported records
3. **Reconcile totals** - Verify AR total, customer count, etc.
4. **Test before go-live** - Use test environment first
5. **Keep backup** - Maintain copy of source files

### Ongoing Use
1. **Document mappings** - Save your column mapping configurations
2. **Train users** - Ensure admins know how to use import tool
3. **Periodic imports** - Import new data as needed
4. **Monitor logs** - Check import logs for issues
5. **Clean up old batches** - Archive or delete old staging data

---

**Version:** 1.0
**Last Updated:** December 27, 2024
**System:** Dunaway Heating & Cooling ERP
