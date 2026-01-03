# Unified Inventory System Documentation

## Overview

The Dunaway Heating & Cooling application now uses a **single source of truth** for all inventory operations. This document describes the canonical inventory model and how to work with it correctly.

---

## Single Source of Truth

### Primary Inventory Table: `part_inventory`

**All inventory quantities are stored and managed in the `part_inventory` table.**

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `part_id` | uuid | Reference to `parts` table |
| `stock_location_id` | uuid | Reference to `stock_locations` table |
| `quantity` | integer | Current quantity at this location |
| `unit_cost` | numeric | Unit cost for this inventory batch |
| `created_at` | timestamptz | Record creation timestamp |
| `updated_at` | timestamptz | Last update timestamp |

**Unique constraint:** `(part_id, stock_location_id)` - Only one inventory record per part per location.

### Location Management: `stock_locations`

All inventory locations are defined in the `stock_locations` table:

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `location_code` | text | Unique location code |
| `name` | text | Location name |
| `location_type` | enum | warehouse, truck, project_site, customer_site, vendor |
| `is_mobile` | boolean | True for trucks/mobile locations |
| `assigned_to_user_id` | uuid | For mobile locations, assigned technician |
| `is_active` | boolean | Location is active/available |

---

## Legacy Fields (Read-Only)

### `parts.quantity_on_hand`

**Status:** Automatically computed, do NOT update directly

This field is maintained by a database trigger that sums all quantities in `part_inventory` for each part. It exists for backwards compatibility and read-only displays.

**Trigger:** `sync_part_quantity_on_inventory_change` automatically updates this field whenever `part_inventory` changes.

### `inventory_balances` table

**Status:** DEPRECATED - Not used

This table was created but never implemented. Do not use it.

### `warehouse_locations` table

**Status:** LEGACY - Superseded by `stock_locations`

This table still exists for reference but all new operations use `stock_locations`.

---

## Inventory Service Layer

**All inventory operations MUST go through `InventoryService`** located at `src/services/InventoryService.ts`.

### Core Methods

#### `getInventoryByPart(partId: string): Promise<PartInventorySummary>`
Get complete inventory breakdown for a part across all locations.

```typescript
const summary = await inventoryService.getInventoryByPart(partId);
// Returns: { partId, totalQuantity, locations: [...] }
```

#### `getInventoryByLocation(locationId: string): Promise<InventoryBalance[]>`
Get all inventory at a specific location.

```typescript
const inventory = await inventoryService.getInventoryByLocation(locationId);
```

#### `getOnHand(partId: string, locationId: string): Promise<number>`
Get quantity available at a specific location.

```typescript
const qty = await inventoryService.getOnHand(partId, locationId);
```

#### `getTotalOnHand(partId: string): Promise<number>`
Get total quantity across all locations.

```typescript
const total = await inventoryService.getTotalOnHand(partId);
```

#### `adjustInventory(adjustment: InventoryAdjustment): Promise<void>`
Adjust inventory at a location.

```typescript
await inventoryService.adjustInventory({
  partId: 'uuid',
  locationId: 'uuid',
  quantity: 5,
  adjustmentType: 'add',  // or 'subtract' or 'set'
  unitCost: 12.50,  // optional
});
```

#### `transferInventory(transfer: InventoryTransfer): Promise<void>`
Transfer inventory between locations.

```typescript
await inventoryService.transferInventory({
  partId: 'uuid',
  fromLocationId: 'uuid',
  toLocationId: 'uuid',
  quantity: 3,
});
```

#### `receiveInventory(partId, locationId, quantity, unitCost?): Promise<void>`
Add inventory when receiving parts.

```typescript
await inventoryService.receiveInventory(
  partId,
  locationId,
  quantity,
  unitCost
);
```

---

## Database Views

### `part_inventory_summary`

Aggregated view of inventory by part:

```sql
SELECT * FROM part_inventory_summary WHERE part_id = 'uuid';
```

Returns: `part_id`, `part_number`, `part_name`, `total_quantity`, `location_count`, `locations_with_stock`

### `part_inventory_details`

Detailed view with full location information:

```sql
SELECT * FROM part_inventory_details WHERE part_id = 'uuid';
```

Returns all part and location details for inventory records.

---

## Rules for Development

### ✅ DO

1. **Always use `InventoryService`** for inventory operations
2. **Read from `part_inventory`** to get current quantities
3. **Use `stock_locations`** for location management
4. **Read from `parts.quantity_on_hand`** for display-only totals
5. **Create inventory records** when receiving parts through `inventoryService.receiveInventory()`
6. **Transfer inventory** between locations using `inventoryService.transferInventory()`

### ❌ DON'T

1. **Never directly UPDATE `parts.quantity_on_hand`** - it's auto-computed
2. **Never directly INSERT/UPDATE/DELETE `part_inventory`** - use the service
3. **Never use `inventory_balances` table** - it's deprecated
4. **Never create new inventory tracking tables** - extend the current system
5. **Never bypass the service layer** for consistency

---

## Migration History

### Applied Migrations

1. **`20251110232306_create_warehouse_locations_and_part_inventory.sql`**
   - Created original `warehouse_locations` and `part_inventory` tables

2. **`20251112024034_create_advanced_parts_ordering_and_serialization_system.sql`**
   - Created `stock_locations`, `inventory_balances` (unused), and related tables

3. **`20251120080619_fix_part_inventory_migrate_to_stock_locations_v2.sql`**
   - Migrated `part_inventory` to use `stock_locations` instead of `warehouse_locations`

4. **`unify_inventory_system_part1.sql`** (Current)
   - Established `part_inventory` as single source of truth
   - Created sync trigger for `parts.quantity_on_hand`
   - Created inventory summary views
   - Marked deprecated tables

---

## Data Flow

### Receiving Parts (Purchase Orders)

```
PO Received
    ↓
inventoryService.receiveInventory()
    ↓
part_inventory INSERT/UPDATE
    ↓
Trigger: sync_part_total_quantity()
    ↓
parts.quantity_on_hand updated
```

### Transferring Parts

```
Transfer Request
    ↓
inventoryService.transferInventory()
    ↓
part_inventory UPDATE (from location -qty)
    ↓
part_inventory UPDATE (to location +qty)
    ↓
inventory_movements INSERT (log entry)
    ↓
Trigger: sync_part_total_quantity()
    ↓
parts.quantity_on_hand updated
```

### Using Parts (Tickets/Projects)

```
Part Used on Ticket
    ↓
inventoryService.adjustInventory()
    ↓
part_inventory UPDATE (location -qty)
    ↓
Trigger: sync_part_total_quantity()
    ↓
parts.quantity_on_hand updated
```

---

## Troubleshooting

### Issue: Quantities don't match across screens

**Solution:** This should no longer happen. All screens now use the same service layer.

If you encounter this:
1. Check that the component is using `InventoryService`
2. Verify the component is not directly querying `part_inventory`
3. Ensure the component is not using cached data

### Issue: parts.quantity_on_hand is incorrect

**Solution:** The trigger should keep this in sync automatically.

To manually fix:
```sql
UPDATE parts p
SET quantity_on_hand = COALESCE((
  SELECT SUM(pi.quantity)::integer
  FROM part_inventory pi
  WHERE pi.part_id = p.id
), 0);
```

### Issue: Need to bulk import inventory

Use the service layer:
```typescript
for (const item of importData) {
  await inventoryService.adjustInventory({
    partId: item.partId,
    locationId: item.locationId,
    quantity: item.quantity,
    adjustmentType: 'set',
  });
}
```

---

## Testing Inventory Consistency

To verify inventory is consistent across the system:

1. Check a part in Parts View - note the total quantity
2. Click "Locations" button - verify sum of location quantities matches
3. Go to Parts Receiving - receive some parts
4. Return to Parts View - verify quantity increased correctly
5. Go to Parts Transfer - transfer parts between locations
6. Verify quantities updated in all views

All quantities should always match across all screens.

---

## Future Enhancements

Potential areas for extension (maintaining single source of truth):

1. **Inventory Snapshots**: Periodic snapshots stored separately for historical reporting
2. **Cycle Counting**: Track count accuracy with `last_counted_at` in inventory records
3. **Allocation System**: Reserve inventory for specific tickets/projects (add `allocated_quantity` to `part_inventory`)
4. **Min/Max Levels**: Per-location reorder points (extend `stock_locations`)
5. **Lot/Batch Tracking**: Add `lot_number` to `part_inventory` for better traceability

All extensions should build on `part_inventory` + `stock_locations` as the foundation.

---

## Serialized Parts & Parent-Child Relationships

### Overview

For expensive, tracked components (compressors, boards, motors), the system supports **serialized parts** with individual tracking and warranty management.

### Key Tables

- **`serialized_parts`**: Individual tracked parts with serial numbers
- **`warranty_records`**: Warranty information linked to each serialized part
- **`equipment`**: Parent equipment (HVAC units) at customer sites

### Parent-Child Relationship

When a serialized part is **installed** on equipment:

```
Equipment (Parent)
  ├── Compressor #12345 (Child - Serialized Part)
  ├── Control Board #XYZ789 (Child - Serialized Part)
  └── Blower Motor #ABC456 (Child - Serialized Part)
```

**Critical Fields in `serialized_parts`:**

| Field | Purpose | When Set |
|-------|---------|----------|
| `current_location_id` | Where the part is physically located | Always (warehouse, truck, etc.) |
| `status` | Current status | Always (in_stock, installed, etc.) |
| `installed_on_equipment_id` | Parent equipment (if installed) | Only when installed |
| `installed_at_site_id` | Customer site (if installed) | Only when installed |
| `installed_on_ticket_id` | Installation work order | Only when installed |

### Location vs Installation Status

**Important distinction:**

- **Location** (`current_location_id`): Where the part IS (warehouse, truck, site)
- **Installation** (`installed_on_equipment_id`): What the part is ATTACHED TO

**Rules:**

1. **In Stock** (warehouse/truck):
   - `status` = 'in_stock' or 'in_transit'
   - `current_location_id` = warehouse or truck ID
   - `installed_on_equipment_id` = NULL
   - **Appears in:** Stock views, vehicle inventory

2. **Installed** (on equipment):
   - `status` = 'installed'
   - `current_location_id` = site/customer location
   - `installed_on_equipment_id` = equipment ID
   - `installed_at_site_id` = customer ID
   - **Appears in:** Equipment detail view, site inventory
   - **Does NOT appear in:** Warehouse/truck stock views

### Database Views for Serialized Parts

#### `serialized_parts_available_stock`
Shows only parts available for use (in warehouses/trucks, not installed):
- Filters: `status IN ('in_stock', 'in_transit')` AND `installed_on_equipment_id IS NULL`
- Use for: Stock screens, vehicle inventory, parts picking

#### `serialized_parts_installed`
Shows only installed parts with full context:
- Filters: `status = 'installed'` OR `installed_on_equipment_id IS NOT NULL`
- Includes: Parent equipment info, site info, warranty status
- Use for: Equipment detail screens, site equipment lists

#### `equipment_with_installed_parts`
Complete equipment view with all child parts:
- Shows equipment with all installed serialized components
- Includes warranty status for each component
- Use for: Customer site equipment reports

### Using InventoryService for Serialized Parts

```typescript
// Get available serialized parts (stock only)
const available = await inventoryService.getSerializedPartsAvailable(locationId);

// Get installed parts on equipment
const installed = await inventoryService.getSerializedPartsInstalled(equipmentId);

// Get all child parts for an equipment unit
const children = await inventoryService.getEquipmentChildParts(equipmentId);

// Get vehicle inventory (both serialized and non-serialized)
const vehicleInv = await inventoryService.getVehicleInventory(vehicleLocationId);

// Transfer serialized part between locations
await inventoryService.transferSerializedPart(
  serializedPartId,
  fromLocationId,
  toLocationId
);

// Install part on equipment
await inventoryService.installSerializedPart(
  serializedPartId,
  equipmentId,
  siteId,
  ticketId,
  installedBy
);

// Uninstall and return to stock
await inventoryService.uninstallSerializedPart(
  serializedPartId,
  returnToLocationId
);
```

### Vehicle Inventory Best Practices

**Jacob's Truck Example:**

```typescript
// Get complete vehicle inventory
const inventory = await inventoryService.getVehicleInventory(jacobsTruckId);

// Returns:
{
  nonSerialized: [
    { partName: "Flame Sensor", quantity: 1, ... }
  ],
  serialized: [
    { serialNumber: "COMP-12345", partName: "Compressor 2-Ton", status: "in_stock", ... }
  ]
}
```

**Critical Rules:**

1. **Transfer** operations update `current_location_id` but NOT installation fields
2. **Install** operations set installation fields AND change `status` to 'installed'
3. Installed parts are automatically filtered from stock views via database views
4. Vehicle views use `vehicle_inventory_with_serials` view for consistency

### Warranty Tracking

Each serialized part can have warranty records:

```sql
SELECT * FROM equipment_with_installed_parts
WHERE equipment_id = 'uuid'
-- Shows all child parts with warranty status computed
```

Warranty status automatically computed:
- **Active**: End date is in the future (>90 days)
- **Expiring Soon**: End date within 90 days
- **Expired**: End date has passed
- **Unknown**: No warranty record exists

### Diagnostic Tools

Use `InventoryDiagnostics` to verify system health:

```typescript
import { inventoryDiagnostics } from './services/InventoryDiagnostics';

// Run complete diagnostic
const report = await inventoryDiagnostics.runFullDiagnostic();

// Get specific vehicle report
const jacobsReport = await inventoryDiagnostics.getVehicleInventoryReport("Jacob's Vehicle");
```

Checks performed:
- Inventory synchronization between tables
- Vehicle inventory consistency
- Serialized parts location/status consistency
- Installed parts not appearing in stock
- Duplicate inventory records

---

## Contact

For questions about the inventory system, contact the development team or refer to:
- `src/services/InventoryService.ts` - Service implementation
- `src/services/InventoryDiagnostics.ts` - Diagnostic tools
- `supabase/migrations/unify_inventory_system_part1.sql` - Database schema
- `supabase/migrations/restore_serialized_parent_child_relationships.sql` - Serialized parts views
