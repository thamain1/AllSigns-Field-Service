import { useEffect, useState } from 'react';
import { Plus, Search, Package, AlertTriangle, TrendingDown, X, Warehouse, MapPin } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import type { Database } from '../../lib/database.types';
import { WarehouseLocationsView } from './WarehouseLocationsView';
import { PartInventoryModal } from './PartInventoryModal';
import { inventoryService } from '../../services/InventoryService';

type Part = Database['public']['Tables']['parts']['Row'];

type PartWithInventory = Part & {
  part_inventory: Array<{
    quantity: number;
    stock_locations: {
      id: string;
      name: string;
    } | null;
  }>;
};

export function PartsView() {
  const [parts, setParts] = useState<PartWithInventory[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<string>('all');
  const [showAddModal, setShowAddModal] = useState(false);
  const [activeTab, setActiveTab] = useState<'inventory' | 'warehouses'>('inventory');
  const [selectedPartForInventory, setSelectedPartForInventory] = useState<{
    id: string;
    name: string;
  } | null>(null);
  const [formData, setFormData] = useState({
    part_number: '',
    name: '',
    description: '',
    manufacturer: '',
    category: '',
    quantity_on_hand: 0,
    reorder_level: 0,
    unit_price: 0,
    location: '',
    warranty_period_months: null as number | null,
    is_serialized: false,
    default_warranty_months: 12,
    vendor_part_number: '',
    reorder_point: 0,
    reorder_quantity: 0,
  });

  useEffect(() => {
    loadParts();
  }, []);

  const loadParts = async () => {
    try {
      const { data, error } = await supabase
        .from('parts')
        .select('*, part_inventory(quantity, stock_locations(name))')
        .order('name', { ascending: true });

      if (error) throw error;
      setParts(data || []);
    } catch (error) {
      console.error('Error loading parts:', error);
    } finally {
      setLoading(false);
    }
  };

  const categories = Array.from(new Set(parts.map((p) => p.category).filter(Boolean)));

  const filteredParts = parts.filter((part) => {
    const matchesSearch =
      part.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      part.part_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      part.manufacturer?.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesCategory = categoryFilter === 'all' || part.category === categoryFilter;

    return matchesSearch && matchesCategory;
  });

  const lowStockParts = parts.filter((p) => p.quantity_on_hand <= p.reorder_level);
  const totalValue = parts.reduce((sum, p) => sum + p.quantity_on_hand * p.unit_price, 0);

  const getStockStatus = (part: Part) => {
    if (part.quantity_on_hand === 0) {
      return { text: 'Out of Stock', class: 'badge badge-red' };
    } else if (part.quantity_on_hand <= part.reorder_level) {
      return { text: 'Low Stock', class: 'badge badge-yellow' };
    } else {
      return { text: 'In Stock', class: 'badge badge-green' };
    }
  };

  const handleAddPart = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      const { error } = await supabase.from('parts').insert([formData]);

      if (error) throw error;

      setShowAddModal(false);
      setFormData({
        part_number: '',
        name: '',
        description: '',
        manufacturer: '',
        category: '',
        quantity_on_hand: 0,
        reorder_level: 0,
        unit_price: 0,
        location: '',
        warranty_period_months: null,
        is_serialized: false,
        default_warranty_months: 12,
        vendor_part_number: '',
        reorder_point: 0,
        reorder_quantity: 0,
      });
      loadParts();
    } catch (error) {
      console.error('Error adding part:', error);
      alert('Failed to add part. Please try again.');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Parts Inventory</h1>
          <p className="text-gray-600 dark:text-gray-400 mt-1">
            Track and manage HVAC parts and supplies
          </p>
        </div>
        {activeTab === 'inventory' && (
          <button
            onClick={() => setShowAddModal(true)}
            className="btn btn-primary flex items-center space-x-2"
          >
            <Plus className="w-5 h-5" />
            <span>Add Part</span>
          </button>
        )}
      </div>

      <div className="card p-1">
        <div className="flex space-x-1">
          <button
            onClick={() => setActiveTab('inventory')}
            className={`flex-1 py-3 px-4 rounded-lg font-medium transition-colors flex items-center justify-center space-x-2 ${
              activeTab === 'inventory'
                ? 'bg-blue-600 text-white'
                : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'
            }`}
          >
            <Package className="w-5 h-5" />
            <span>Parts Inventory</span>
          </button>
          <button
            onClick={() => setActiveTab('warehouses')}
            className={`flex-1 py-3 px-4 rounded-lg font-medium transition-colors flex items-center justify-center space-x-2 ${
              activeTab === 'warehouses'
                ? 'bg-blue-600 text-white'
                : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'
            }`}
          >
            <Warehouse className="w-5 h-5" />
            <span>Warehouse Locations</span>
          </button>
        </div>
      </div>

      {activeTab === 'warehouses' ? (
        <WarehouseLocationsView />
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Total Parts</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                {parts.length}
              </p>
            </div>
            <div className="bg-blue-100 dark:bg-blue-900/20 text-blue-600 p-3 rounded-lg">
              <Package className="w-6 h-6" />
            </div>
          </div>
        </div>

        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Low Stock Items</p>
              <p className="text-3xl font-bold text-red-600 mt-2">{lowStockParts.length}</p>
            </div>
            <div className="bg-red-100 dark:bg-red-900/20 text-red-600 p-3 rounded-lg">
              <AlertTriangle className="w-6 h-6" />
            </div>
          </div>
        </div>

        <div className="card p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400">Inventory Value</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                ${totalValue.toFixed(2)}
              </p>
            </div>
            <div className="bg-green-100 dark:bg-green-900/20 text-green-600 p-3 rounded-lg">
              <TrendingDown className="w-6 h-6" />
            </div>
          </div>
        </div>
      </div>

      <div className="card p-6">
        <div className="flex flex-col md:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search parts, part numbers, manufacturers..."
              className="input pl-10"
            />
          </div>

          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="input md:w-64"
          >
            <option value="all">All Categories</option>
            {categories.map((cat) => (
              <option key={cat} value={cat}>
                {cat}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 dark:bg-gray-700">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Part Number
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Manufacturer
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Category
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Quantity
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Unit Price
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Location
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              {filteredParts.length === 0 ? (
                <tr>
                  <td colSpan={9} className="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
                    No parts found
                  </td>
                </tr>
              ) : (
                filteredParts.map((part) => {
                  const status = getStockStatus(part);
                  return (
                    <tr
                      key={part.id}
                      className="hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
                    >
                      <td className="px-6 py-4">
                        <span className="font-medium text-gray-900 dark:text-white">
                          {part.part_number}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <div>
                          <span className="text-gray-900 dark:text-white">{part.name}</span>
                          {part.description && (
                            <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                              {part.description}
                            </p>
                          )}
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-gray-900 dark:text-white">
                          {part.manufacturer || 'N/A'}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-gray-900 dark:text-white">
                          {part.category || 'Uncategorized'}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <div>
                          <span className="font-medium text-gray-900 dark:text-white">
                            {part.quantity_on_hand}
                          </span>
                          {part.quantity_on_hand <= part.reorder_level && (
                            <p className="text-xs text-red-600 mt-1">
                              Reorder at: {part.reorder_level}
                            </p>
                          )}
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-gray-900 dark:text-white">
                          ${part.unit_price.toFixed(2)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className={status.class}>{status.text}</span>
                      </td>
                      <td className="px-6 py-4">
                        {part.part_inventory && part.part_inventory.length > 0 ? (
                          <div className="space-y-1">
                            {part.part_inventory.map((inv, idx) => (
                              <div key={idx} className="text-xs">
                                <span className="font-medium text-gray-900 dark:text-white">
                                  {inv.stock_locations?.name || 'Unknown'}
                                </span>
                                <span className="text-gray-500 dark:text-gray-400 ml-1">
                                  ({inv.quantity})
                                </span>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <span className="text-gray-500 dark:text-gray-400 text-xs">
                            Not assigned
                          </span>
                        )}
                      </td>
                      <td className="px-6 py-4">
                        <button
                          onClick={() =>
                            setSelectedPartForInventory({ id: part.id, name: part.name })
                          }
                          className="btn btn-outline p-2 flex items-center space-x-1"
                          title="Manage inventory by location"
                        >
                          <MapPin className="w-4 h-4" />
                          <span className="text-xs">Locations</span>
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {lowStockParts.length > 0 && (
        <div className="card p-6 bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800">
          <div className="flex items-start space-x-3">
            <AlertTriangle className="w-5 h-5 text-red-600 mt-0.5" />
            <div className="flex-1">
              <h3 className="font-bold text-red-900 dark:text-red-200">Low Stock Alert</h3>
              <p className="text-sm text-red-700 dark:text-red-300 mt-1">
                {lowStockParts.length} parts need to be reordered
              </p>
              <div className="mt-3 space-y-1">
                {lowStockParts.slice(0, 5).map((part) => (
                  <p key={part.id} className="text-sm text-red-600 dark:text-red-400">
                    {part.name} ({part.part_number}) - Only {part.quantity_on_hand} remaining
                  </p>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {showAddModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden flex flex-col">
            <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
              <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Add New Part</h2>
              <button
                onClick={() => setShowAddModal(false)}
                className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleAddPart} className="p-6 overflow-y-auto flex-1">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Part Number *
                  </label>
                  <input
                    type="text"
                    required
                    value={formData.part_number}
                    onChange={(e) => setFormData({ ...formData, part_number: e.target.value })}
                    className="input"
                    placeholder="e.g., CAP-123-XYZ"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Part Name *
                  </label>
                  <input
                    type="text"
                    required
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    className="input"
                    placeholder="e.g., Compressor Capacitor"
                  />
                </div>

                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Description
                  </label>
                  <textarea
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    className="input"
                    rows={2}
                    placeholder="Enter part description"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Manufacturer
                  </label>
                  <input
                    type="text"
                    value={formData.manufacturer}
                    onChange={(e) => setFormData({ ...formData, manufacturer: e.target.value })}
                    className="input"
                    placeholder="e.g., Carrier"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Category
                  </label>
                  <input
                    type="text"
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="input"
                    placeholder="e.g., Electrical"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Quantity on Hand *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    value={formData.quantity_on_hand}
                    onChange={(e) =>
                      setFormData({ ...formData, quantity_on_hand: parseInt(e.target.value) || 0 })
                    }
                    className="input"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Reorder Level *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    value={formData.reorder_level}
                    onChange={(e) =>
                      setFormData({ ...formData, reorder_level: parseInt(e.target.value) || 0 })
                    }
                    className="input"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Unit Price *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    step="0.01"
                    value={formData.unit_price}
                    onChange={(e) =>
                      setFormData({ ...formData, unit_price: parseFloat(e.target.value) || 0 })
                    }
                    className="input"
                    placeholder="0.00"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Storage Location
                  </label>
                  <input
                    type="text"
                    value={formData.location}
                    onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                    className="input"
                    placeholder="e.g., Warehouse A, Shelf 3"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    OEM Warranty Period (Months)
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={formData.warranty_period_months ?? ''}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        warranty_period_months: e.target.value ? parseInt(e.target.value) : null,
                      })
                    }
                    className="input"
                    placeholder="e.g., 12"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Vendor Part Number
                  </label>
                  <input
                    type="text"
                    value={formData.vendor_part_number}
                    onChange={(e) => setFormData({ ...formData, vendor_part_number: e.target.value })}
                    className="input"
                    placeholder="Vendor's part number"
                  />
                </div>

                <div className="md:col-span-2">
                  <label className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      checked={formData.is_serialized}
                      onChange={(e) => setFormData({ ...formData, is_serialized: e.target.checked })}
                      className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                    <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                      Track by Serial Number
                    </span>
                  </label>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-1 ml-6">
                    Enable this for parts that require individual serial number tracking (e.g., compressors, condensers)
                  </p>
                </div>

                {formData.is_serialized && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                      Default Warranty (Months)
                    </label>
                    <input
                      type="number"
                      min="0"
                      value={formData.default_warranty_months}
                      onChange={(e) =>
                        setFormData({ ...formData, default_warranty_months: parseInt(e.target.value) || 12 })
                      }
                      className="input"
                      placeholder="12"
                    />
                    <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                      Default warranty period for serialized units
                    </p>
                  </div>
                )}
              </div>

              <div className="flex space-x-3 mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="btn btn-outline flex-1"
                >
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary flex-1">
                  Add Part
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {selectedPartForInventory && (
        <PartInventoryModal
          partId={selectedPartForInventory.id}
          partName={selectedPartForInventory.name}
          onClose={() => setSelectedPartForInventory(null)}
        />
      )}
        </>
      )}
    </div>
  );
}
